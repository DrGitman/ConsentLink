import 'dart:convert';

import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/language/review_status.dart';
import 'package:consentlink/ai/language/translated_form_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Invented test data shaped like forms/consent-form.<code>.json.
const _formReviewer = {
  'name': 'Form Reviewer',
  'fluency': 'first_language',
  'date': '2026-10-01',
};

Map<String, Object?> _sectionJson({
  String status = 'machine_draft',
  Map<String, Object?>? reviewer,
}) => {
  'key': 'purpose',
  'required_element': 'purpose',
  'title': 'Title',
  'text': 'Translated text with a click ǃ.',
  'required': true,
  'status': status,
  'reading_grade': 5,
  'reviewer': ?reviewer,
};

String _formJson({
  Object? sections,
  Map<String, Object?> reviewer = const {
    'name': null,
    'fluency': null,
    'date': null,
  },
  String? iso = 'ktz',
  String language = "Ju/'hoansi",
}) => jsonEncode({
  'id': 'consent-master-v1',
  'language': language,
  'iso639_3': ?iso,
  'version': '0.1.0',
  'status': 'awaiting_translation',
  'sections': sections ?? [_sectionJson()],
  'reviewer': reviewer,
});

Matcher _formatError(String part) => throwsA(
  isA<LanguagePackFormatException>().having(
    (error) => error.message,
    'message',
    contains(part),
  ),
);

void main() {
  group('parses', () {
    test('a translated form', () {
      final form = parseTranslatedForm(_formJson());
      final section = form.sections.single;

      expect(form.languageCode, 'ktz');
      expect(section.element, ConsentElement.purpose);
      expect(section.status, ReviewStatus.machineDraft);
      expect(section.text, contains('ǃ'));
      expect(section.reviewer, isNull);
    });

    test('an untranslated shell with empty sections', () {
      expect(parseTranslatedForm(_formJson(sections: {})).sections, isEmpty);
    });

    test('an ISO 639-3 code into the app language code', () {
      expect(parseTranslatedForm(_formJson(iso: 'her')).languageCode, 'hz');
    });

    test('an app language code written as the ISO code', () {
      expect(parseTranslatedForm(_formJson(iso: 'de')).languageCode, 'de');
    });

    test('the language field when there is no ISO code', () {
      expect(
        parseTranslatedForm(_formJson(iso: null, language: 'en')).languageCode,
        'en',
      );
    });

    test('the section reviewer first, else the form reviewer', () {
      final own = {..._formReviewer, 'name': 'Section Reviewer'};
      final form = parseTranslatedForm(
        _formJson(
          reviewer: _formReviewer,
          sections: [
            _sectionJson(status: 'reviewed', reviewer: own),
            {..._sectionJson(status: 'reviewed'), 'key': 'other'},
          ],
        ),
      );

      expect(form.sections.map((s) => s.reviewer?.name), [
        'Section Reviewer',
        'Form Reviewer',
      ]);
      expect(form.isReadyForParticipants, isTrue);
    });
  });

  group('rejects', () {
    test('invalid JSON', () {
      expect(() => parseTranslatedForm('{'), _formatError('Invalid JSON'));
    });

    test('an unknown language code', () {
      expect(
        () => parseTranslatedForm(_formJson(iso: 'xyz')),
        _formatError('Unknown language "xyz"'),
      );
    });

    test('a display name instead of a language code', () {
      expect(
        () => parseTranslatedForm(_formJson(iso: null)),
        _formatError('Unknown language'),
      );
    });

    test('a missing field', () {
      final section = _sectionJson()..remove('title');

      expect(
        () => parseTranslatedForm(_formJson(sections: [section])),
        _formatError('Missing "title"'),
      );
    });

    test('an unknown status', () {
      expect(
        () => parseTranslatedForm(
          _formJson(sections: [_sectionJson(status: 'done')]),
        ),
        _formatError('Unknown value "done"'),
      );
    });

    test('reviewed by a learner', () {
      final learner = {..._formReviewer, 'fluency': 'learner'};

      expect(
        () => parseTranslatedForm(
          _formJson(
            sections: [_sectionJson(status: 'reviewed', reviewer: learner)],
          ),
        ),
        _formatError('Invalid form'),
      );
    });

    test('an invalid reviewer date', () {
      expect(
        () => parseTranslatedForm(
          _formJson(reviewer: {..._formReviewer, 'date': 'soon'}),
        ),
        _formatError('Invalid reviewer date'),
      );
    });
  });
}
