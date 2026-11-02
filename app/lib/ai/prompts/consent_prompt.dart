import 'dart:convert';

import '../domain/consent_element.dart';
import '../llm/llm_runtime.dart';
import '../pdf/proposal_page.dart';
import 'element_guidance.dart';
import 'section_grammar.dart';

/// Forms are drafted in English; translation is out of scope for now.
const draftLanguage = 'en';

/// Room for one compact section: ~150 tokens of text plus quote, changes
/// and JSON keys (benchmark, 2026-11-02).
const sectionMaxTokens = 512;

/// Rules shared by every section call (decision D5.3: zero-shot, with the
/// answer shape in the user message).
const consentSystemPrompt = '''
You write one section of an informed consent form from pages of a research proposal.
The reader may have a Grade 6 reading level.

Rules:
- Use only facts from the proposal pages. Never invent names, numbers or contacts.
- Use short sentences and everyday words. Speak to the reader as "you".
- State rights plainly: taking part is a free choice, and the reader can ask questions at any time.
- "title": a short heading in plain words.
- "text": the section, in 2 to 5 short sentences.
- "source_pages": the numbers of the "[Page N]" pages you used.
- "source_quote": a short exact quote from those pages.
- "changes": each simplification you made, such as "Replaced 'remuneration' with 'payment'".
- "confidence": "high" if the pages say it clearly, "medium" if you combined or inferred, "low" if they barely cover it.
- If the pages do not cover the element, put its key in "missing" and leave "sections" empty.''';

/// The model request that drafts the section of [element] from [pages].
///
/// Throws an [ArgumentError] when [pages] is empty.
LlmPrompt buildSectionPrompt(ConsentElement element, List<ProposalPage> pages) {
  if (pages.isEmpty) {
    throw ArgumentError.value(pages, 'pages', 'Is empty');
  }
  return LlmPrompt(
    system: consentSystemPrompt,
    user: _userMessage(element, pages),
    maxTokens: sectionMaxTokens,
    grammar: sectionGrammar(element, draftLanguage),
  );
}

String _userMessage(ConsentElement element, List<ProposalPage> pages) {
  final pageBlocks = [
    for (final page in pages) '[Page ${page.pageNumber}]\n${page.text}',
  ];
  return [
    'Element key: ${element.jsonKey}',
    'Instruction: ${elementGuidance[element]!.instruction}',
    'Proposal pages:',
    ...pageBlocks,
    _answerShapes(element, pages.first.pageNumber),
  ].join('\n\n');
}

// Placeholders of the answer shape; the system prompt says how to fill them.
const _titlePlaceholder = '<heading>';
const _textPlaceholder = '<section text>';
const _quotePlaceholder = '<exact quote>';
const _changePlaceholder = '<change>';
const _confidencePlaceholder = '<low|medium|high>';

/// The two allowed answers, spelled out because the grammar is off on the
/// phone (D5.6b): the model must not guess the `/schemas` envelope.
String _answerShapes(ConsentElement element, int examplePage) {
  final found = jsonEncode({
    'form_language': draftLanguage,
    'reading_grade': null,
    'sections': [
      {
        'key': element.jsonKey,
        'title': _titlePlaceholder,
        'text': _textPlaceholder,
        'source_pages': [examplePage],
        'source_quote': _quotePlaceholder,
        'changes': [_changePlaceholder],
        'confidence': _confidencePlaceholder,
      },
    ],
    'missing': <String>[],
  });
  return 'Answer with one JSON object only, in this shape:\n$found\n\n'
      'If the pages do not cover the element, answer exactly:\n'
      '${missingAnswerFor(element)}';
}

/// The exact answer for an element the pages do not cover.
String missingAnswerFor(ConsentElement element) => jsonEncode({
  'form_language': draftLanguage,
  'reading_grade': null,
  'sections': <Object>[],
  'missing': [element.jsonKey],
});
