import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_exceptions.dart';
import '../../ai/ai_providers.dart';
import '../../ai/llm/llm_model_config.dart';
import '../../ai/language/orthography.dart';
import '../../ai/language/orthography_normaliser.dart';
import '../../ai/llm/llm_runtime.dart';
import '../../ai/rules/readability.dart';
import '../../ai/service/device_memory.dart';
import '../../contracts/languages.dart';

/// Small on-device model calls for the helpers around drafting: simpler
/// wording (04.4) and the template assistant (05.4). The model is loaded
/// for one answer and released, like drafting. Nothing leaves the phone.
///
/// When the model is not on the phone (or the phone has too little memory)
/// every helper falls back to fixed rules, so it still works, and says so.
class OnDeviceAssistant {
  OnDeviceAssistant(
    this._runtime, {
    this.modelPath = deviceModelPath,
    this.totalMemoryBytes = readTotalMemoryBytes,
  });

  final LlmRuntime _runtime;
  final Future<String> Function() modelPath;
  final Future<int?> Function() totalMemoryBytes;

  Future<bool> isAvailable() async {
    try {
      await modelPath();
    } on ModelNotFoundException {
      return false;
    }
    final memory = await totalMemoryBytes();
    return memory != null && memory >= minimumMemoryBytes;
  }

  /// One answer from the model, as plain text.
  Future<String> ask({
    required String system,
    required String user,
    int maxTokens = 400,
  }) async {
    await _runtime.load(LlmModelConfig(modelPath: await modelPath()));
    try {
      final out = StringBuffer();
      await for (final piece in _runtime.generate(
        LlmPrompt(system: system, user: user, maxTokens: maxTokens),
      )) {
        out.write(piece);
      }
      return out.toString().replaceAll(RegExp(r'<[^>]*\|?>'), '').trim();
    } finally {
      await _runtime.dispose();
    }
  }
}

final onDeviceAssistantProvider = Provider<OnDeviceAssistant>(
  (ref) => OnDeviceAssistant(ref.watch(llmRuntimeProvider)),
);

// ---- Simpler wording (04.4) ----

class Rewording {
  const Rewording({
    required this.text,
    required this.changes,
    required this.byModel,
    this.gradeBefore,
    this.gradeAfter,
  });
  final String text;
  final List<String> changes;

  /// True when the on-device model wrote it, false for the word list.
  final bool byModel;
  final double? gradeBefore;
  final double? gradeAfter;

  bool get changed => changes.isNotEmpty;
}

const _rewordSystem =
    'You rewrite one section of a research consent form for participants in '
    'Namibia. Use plain English a 12 year old understands: short sentences, '
    'common words, and "you" for the participant. Keep every fact, number, '
    'name, phone number, time and right exactly. Never add a fact, promise or '
    'risk that is not in the text. Reply with the rewritten section only.';

/// Simpler wording for [text]. Uses the on-device model when it is on this
/// phone, else the word list. A model answer that drops a number or comes
/// back empty is not used (the word list is used instead).
Future<Rewording> simplerWording(
  OnDeviceAssistant assistant,
  String text, {
  String language = 'en',
}) async {
  final before = readingGradeOf(text, language);
  if (language == 'en' && await assistant.isAvailable()) {
    try {
      final answer = await assistant.ask(system: _rewordSystem, user: text);
      if (answer.isNotEmpty && keepsNumbers(text, answer) && answer != text) {
        final after = readingGradeOf(answer, language);
        return Rewording(
          text: answer,
          changes: [
            'Rewritten in plain English by the on-device AI',
            if (before != null && after != null)
              'Reading level: grade ${before.round()} → grade ${after.round()}',
          ],
          byModel: true,
          gradeBefore: before,
          gradeAfter: after,
        );
      }
    } on Exception {
      // Fall through to the word list.
    }
  }
  final rules = ruleSimplify(text);
  return Rewording(
    text: rules.$1,
    changes: rules.$2,
    byModel: false,
    gradeBefore: before,
    gradeAfter: readingGradeOf(rules.$1, language),
  );
}

/// Every number in [source] is still in [result] (digits only).
bool keepsNumbers(String source, String result) {
  final numbers = RegExp(r'\d+').allMatches(source).map((m) => m.group(0)!);
  final kept = RegExp(
    r'\d+',
  ).allMatches(result).map((m) => m.group(0)!).toSet();
  return numbers.every(kept.contains);
}

/// Plain words for common consent form jargon.
const plainWords = {
  'semi-structured interview': 'interview',
  'semi structured interview': 'interview',
  'approximately': 'about',
  'participate in': 'take part in',
  'participate': 'take part',
  'participation': 'taking part',
  'participants': 'people taking part',
  'utilise': 'use',
  'utilize': 'use',
  'commence': 'start',
  'terminate': 'stop',
  'discontinue': 'stop',
  'remuneration': 'payment',
  'compensation': 'payment',
  'subsequently': 'later',
  'in order to': 'to',
  'prior to': 'before',
  'sufficient': 'enough',
  'assist': 'help',
  'obtain': 'get',
  'require': 'need',
  'requires': 'needs',
  'additional': 'more',
  'regarding': 'about',
  'with regard to': 'about',
  'in the event that': 'if',
  'at any point in time': 'at any time',
  'without penalty': 'and nothing bad will happen to you',
  'anonymised': 'without your name',
  'anonymized': 'without your name',
  'confidential': 'private',
  'disseminate': 'share',
  'dissemination': 'sharing',
  'fatigue': 'tiredness',
  'duration': 'length',
  'individuals': 'people',
  'facilitate': 'help',
  'indicate': 'show',
  'whereby': 'where',
  'thereafter': 'after that',
  'is able to': 'can',
  'are able to': 'can',
  'voluntary': 'your choice',
  'investigator': 'researcher',
};

/// The word list applied to [text]: (new text, what changed).
(String, List<String>) ruleSimplify(String text) {
  var out = text;
  final changes = <String>[];
  final keys = plainWords.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final hard in keys) {
    final pattern = RegExp(
      '\\b${RegExp.escape(hard)}\\b',
      caseSensitive: false,
    );
    if (!pattern.hasMatch(out)) continue;
    final easy = plainWords[hard]!;
    out = out.replaceAllMapped(pattern, (m) {
      final word = m.group(0)!;
      return word[0] == word[0].toUpperCase() &&
              word[0] != word[0].toLowerCase()
          ? easy[0].toUpperCase() + easy.substring(1)
          : easy;
    });
    changes.add('Replaced “$hard” with “$easy”');
  }
  // Long sentences joined by ";" become two sentences.
  final split = out.replaceAllMapped(
    RegExp(r';\s+([a-z])'),
    (m) => '. ${m.group(1)!.toUpperCase()}',
  );
  if (split != out) {
    changes.add('Split long sentences in two');
    out = split;
  }
  return (out, changes);
}

// ---- Template assistant (05.4) ----

const _templateSystem =
    'You turn a researcher\'s description of a consent form template into a '
    'short checklist of layout rules. One rule per line, starting with "- ". '
    'Use only what they asked for, in at most 8 words per rule. Allowed kinds: '
    'footer, header, logo, font, margins, columns or languages, witness block, '
    'thumbprint box, signature block, date line, page numbers. No other text.';

/// Checklist items for a template description. The model when it is on the
/// phone, else rules that read the same kinds of request.
Future<(List<String>, bool)> templateItemsFor(
  OnDeviceAssistant assistant,
  String request,
) async {
  if (await assistant.isAvailable()) {
    try {
      final answer = await assistant.ask(
        system: _templateSystem,
        user: request,
        maxTokens: 200,
      );
      final items = [
        for (final line in answer.split('\n'))
          if (line.trim().startsWith('- ') && line.trim().length > 3)
            line.trim().substring(2).trim(),
      ];
      if (items.isNotEmpty) return (items.take(8).toList(), true);
    } on Exception {
      // Fall through to the rules.
    }
  }
  return (ruleTemplateItems(request), false);
}

/// Reads a template request with fixed rules (no model needed).
List<String> ruleTemplateItems(String request) {
  final text = request.toLowerCase();
  final items = <String>[];
  if (text.contains('footer')) {
    items.add(
      RegExp(r'\b(rec|hrec|ethics|reference|ref)\b').hasMatch(text)
          ? 'Footer: “HREC ref: {ethics_no}” + page numbers'
          : 'Footer: page numbers',
    );
  } else if (text.contains('page number')) {
    items.add('Footer: page numbers');
  }
  if (text.contains('header')) items.add('Header: study title and institution');
  if (text.contains('logo')) items.add('Institution logo at the top');
  if (text.contains('witness'))
    items.add('Witness name, signature & date block');
  if (text.contains('thumb')) items.add('Thumbprint box next to the signature');
  final named = [
    for (final l in consentLanguages)
      if (l.code != 'en' && text.contains(l.displayName.toLowerCase()))
        l.displayName,
  ];
  if (named.isNotEmpty || text.contains('column')) {
    items.add(
      'Two columns: English | ${named.isEmpty ? 'participant language' : named.join(' | ')}',
    );
  }
  final font = RegExp(
    r'([a-z][a-z ]*?)\s*(\d{1,2})\s*(pt|point)',
  ).firstMatch(text);
  final margin = RegExp(r'(\d+(?:[.,]\d+)?)\s*cm').firstMatch(text);
  if (font != null) {
    final family = font.group(1)!.trim().split(' ').last;
    items.add(
      'Font: ${family[0].toUpperCase()}${family.substring(1)} ${font.group(2)} pt',
    );
  }
  if (margin != null)
    items.add('Margins: ${margin.group(1)!.replaceAll(',', '.')} cm');
  if (font == null && margin == null)
    items.add('Keeps Arial 11 pt and 2.5 cm margins');
  if (items.length == 1 && request.trim().isNotEmpty) {
    items.insert(0, 'Note: ${request.trim()}');
  }
  return items;
}

// ---- Translation drafts (04.3 participant languages) ----

/// The team's dictionary file for an app language code
/// (assets/language, from consentlink-language-packs).
const _dictionaryFiles = {
  'af': 'dictionary.af.json',
  'de': 'dictionary.de.json',
  'hz': 'dictionary.her.json',
  'naq': 'dictionary.naq.json',
  'ktz': 'dictionary.ktz.json',
  'kwn': 'dictionary.kwn.json',
  'loz': 'dictionary.loz.json',
  'ng': 'dictionary.ng.json',
};

class GlossaryEntry {
  const GlossaryEntry(this.english, this.target, this.status);
  final String english;
  final String target;
  final String status;
}

/// Dictionary entries whose English term appears in [english].
Future<List<GlossaryEntry>> glossaryFor(String code, String english) async {
  final file = _dictionaryFiles[code];
  if (file == null) return const [];
  try {
    final json =
        jsonDecode(await rootBundle.loadString('assets/language/$file'))
            as Map<String, dynamic>;
    final entries =
        (json['entries'] as Map<String, dynamic>? ?? const {}).values;
    final text = english.toLowerCase();
    return [
      for (final e in entries.cast<Map<String, dynamic>>())
        if (e['target'] is String &&
            (e['target'] as String).trim().isNotEmpty &&
            e['en'] is String &&
            RegExp(
              '\\b${RegExp.escape((e['en'] as String).toLowerCase())}\\b',
            ).hasMatch(text))
          GlossaryEntry(
            e['en'] as String,
            e['target'] as String,
            e['status'] as String? ?? 'machine_draft',
          ),
    ];
  } catch (_) {
    return const [];
  }
}

class TranslationDraft {
  const TranslationDraft(this.text, this.glossary);
  final String text;
  final List<GlossaryEntry> glossary;
}

/// A machine draft of [english] in [code] by the on-device model, guided by
/// the team's dictionary for that language. Never shown to a participant as
/// it is: the translation sheet still needs a first-language or fluent
/// reviewer (language pack rule: machine_draft < reviewed). Null when the
/// model is not on this phone.
Future<TranslationDraft?> draftTranslation(
  OnDeviceAssistant assistant,
  String english,
  String code,
) async {
  if (!await assistant.isAvailable()) return null;
  final language = languageName(code);
  final glossary = await glossaryFor(code, english);
  final terms = glossary.isEmpty
      ? ''
      : '\nUse these words from the team dictionary:\n'
            '${glossary.map((g) => '${g.english} = ${g.target}').join('\n')}';
  final clicks = code == 'naq' || code == 'ktz'
      ? '\nWrite click letters as ǀ ǁ ǂ ǃ (never | / # !).'
      : '';
  final answer = await assistant.ask(
    system:
        'You translate one section of a research consent form from English into '
        '$language for participants in Namibia. Short, plain sentences. Keep every '
        'number, name, phone number and {placeholder} exactly. Do not add or drop '
        'anything. Reply with the $language text only.$clicks$terms',
    user: english,
    maxTokens: 500,
  );
  if (answer.isEmpty || !keepsNumbers(english, answer)) return null;
  final text = switch (code) {
    'naq' => normaliseLanguageText(answer, khoekhoegowab),
    'ktz' => normaliseLanguageText(answer, juHoansi),
    _ => answer,
  };
  return TranslationDraft(text, glossary);
}
