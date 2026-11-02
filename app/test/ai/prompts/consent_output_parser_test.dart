import 'dart:convert';

import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/domain/generated_section.dart';
import 'package:consentlink/ai/prompts/consent_output_parser.dart';
import 'package:consentlink/contracts/models.dart' show Confidence;
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/khoekhoegowab_fixture.dart';

// Invented model output; not from a real proposal.
Map<String, Object?> _section({
  Object? key = 'risks',
  Object? text = 'You may feel tired. You can rest or stop at any time.',
  Object? sourcePages = const [6],
  Object? confidence = 'medium',
  String? source,
  Map<String, Object?> extra = const {},
}) => {
  'key': key,
  'title': 'Risks',
  'text': text,
  'source_pages': sourcePages,
  'source_quote': 'Participants may experience mild fatigue.',
  'changes': ['Replaced jargon'],
  'confidence': confidence,
  'source': ?source,
  ...extra,
};

String _output(
  List<Object?> sections, {
  Object? language = 'en',
  Object? grade = 6.2,
  List<Object?> missing = const ['contacts_ethics'],
  Map<String, Object?> extra = const {},
}) => jsonEncode({
  'form_language': language,
  'reading_grade': grade,
  'sections': sections,
  'missing': missing,
  ...extra,
});

Matcher _invalidOutput(String messagePart) => throwsA(
  isA<InvalidModelOutputException>().having(
    (error) => error.message,
    'message',
    contains(messagePart),
  ),
);

void main() {
  test('reads a valid output into the draft model', () {
    final parsed = parseConsentDraft(_output([_section()]));

    final section = parsed.draft.sections.single;
    expect(section.element, ConsentElement.risks);
    expect(section.sourcePages, [6]);
    expect(section.confidence, Confidence.medium);
    expect(section.source, SectionSource.proposal);
    expect(parsed.draft.formLanguage, 'en');
    expect(parsed.draft.readingGrade, 6.2);
    expect(parsed.draft.missing, [ConsentElement.contactsEthics]);
    expect(parsed.issues, isEmpty);
  });

  test('a template section may have no source pages', () {
    final parsed = parseConsentDraft(
      _output([_section(sourcePages: const [], source: 'template')]),
    );
    expect(parsed.draft.sections.single.source, SectionSource.template);
  });

  test('ignores text around the JSON object, such as a fence', () {
    final fenced = 'Here is the form:\n```json\n${_output([_section()])}\n```';
    expect(parseConsentDraft(fenced).draft.sections, hasLength(1));
  });

  group('a broken root throws', () {
    final cases = {
      'No JSON object': 'Sorry, I cannot.',
      'not valid JSON': '{"sections": [}',
      'Missing "missing"': jsonEncode({'form_language': 'en', 'sections': []}),
      'Unknown "form_language"': _output([], language: 'fr'),
      'Invalid "readingGrade"': _output([], grade: -1),
    };
    for (final MapEntry(key: message, value: output) in cases.entries) {
      test(message, () {
        expect(() => parseConsentDraft(output), _invalidOutput(message));
      });
    }
  });

  group('a broken section is dropped and listed as missing', () {
    final cases = {
      'unknown key': _section(key: 'rights'),
      'blank text': _section(text: '  '),
      'bad confidence': _section(confidence: 0.9),
      'unknown confidence': _section(confidence: 'very high'),
      'empty pages': _section(sourcePages: const []),
      'page 0': _section(sourcePages: const [0]),
      'pages as text': _section(sourcePages: const ['6']),
    };
    for (final MapEntry(key: name, value: section) in cases.entries) {
      test(name, () {
        final parsed = parseConsentDraft(_output([section]));
        expect(parsed.draft.sections, isEmpty);
        expect(parsed.issues.single, startsWith('Section 1 dropped'));
        expect(
          parsed.issues.single,
          isNot(contains('tired')),
          reason: 'no form text',
        );
        if (name != 'unknown key') {
          expect(parsed.draft.missing, contains(ConsentElement.risks));
        }
      });
    }

    test('a duplicate key keeps the first section', () {
      final parsed = parseConsentDraft(
        _output([_section(), _section(text: 'Another text.')]),
      );
      expect(parsed.draft.sections.single.text, startsWith('You may'));
      expect(parsed.draft.missing, isNot(contains(ConsentElement.risks)));
      expect(parsed.issues.single, contains('Duplicate'));
    });
  });

  test('a key both drafted and missing counts as drafted', () {
    final parsed = parseConsentDraft(
      _output([_section()], missing: const ['risks']),
    );
    expect(parsed.draft.missing, isEmpty);
  });

  test('unknown fields are ignored and noted', () {
    final parsed = parseConsentDraft(
      _output(
        [
          _section(extra: const {'notes': 'x'}),
        ],
        extra: const {'model': 'x'},
        missing: const ['contacts_ethics', 'rights'],
      ),
    );
    expect(parsed.draft.sections, hasLength(1));
    expect(parsed.issues, hasLength(3));
  });

  test('keeps the four click letters unchanged (task K)', () {
    final parsed = parseConsentDraft(
      _output([
        _section(text: khoekhoegowabSentence),
      ], language: khoekhoegowabCode),
    );
    final text = parsed.draft.sections.single.text;
    expect(text, khoekhoegowabSentence);
    expect(allClickLetters.every(text.contains), isTrue);
  });
}
