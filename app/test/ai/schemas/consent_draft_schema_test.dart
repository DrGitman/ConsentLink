import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

// Paths are relative to app/, where `flutter test` runs.
const _consentDraftSchemaPath = '../schemas/consent_draft.schema.json';
const _ruleReportSchemaPath = '../schemas/rule_report.schema.json';

JsonSchema _load(String path) =>
    JsonSchema.create(File(path).readAsStringSync());

// Invented test data; not from a real proposal.
Map<String, Object?> _section({
  String key = 'risks',
  List<int> sourcePages = const [6],
  String confidence = 'high',
  String? source,
}) => {
  'key': key,
  'title': 'Risks & discomforts',
  'text': 'You may feel tired. You can rest or stop at any time.',
  'source_pages': sourcePages,
  'source_quote': 'Participants may experience mild fatigue.',
  'changes': ['Replaced jargon', 'Added no penalty'],
  'confidence': confidence,
  'source': ?source,
};

Map<String, Object?> _draft(List<Map<String, Object?>> sections) => {
  'form_language': 'en',
  'reading_grade': 6,
  'sections': sections,
  'missing': ['contacts_ethics'],
};

Map<String, Object?> _item(String status, {String? fixHint}) => {
  'key': 'contacts_ethics',
  'status': status,
  'fix_hint': ?fixHint,
};

Map<String, Object?> _report(List<Map<String, Object?>> items) => {
  'found': 9,
  'required': 10,
  'items': items,
};

void main() {
  group('consent_draft.schema.json', () {
    final schema = _load(_consentDraftSchemaPath);
    bool isValid(Object? json) => schema.validate(json).isValid;

    test('accepts the Figma G example', () {
      expect(isValid(_draft([_section()])), isTrue);
    });

    test('accepts a minors key', () {
      expect(isValid(_draft([_section(key: 'child_assent')])), isTrue);
    });

    test('rejects a key outside the 14 required elements', () {
      expect(isValid(_draft([_section(key: 'storage')])), isFalse);
    });

    test('rejects a numeric confidence', () {
      final section = {..._section(), 'confidence': 0.9};
      expect(isValid(_draft([section])), isFalse);
    });

    test('rejects an unknown field', () {
      final section = {..._section(), 'section_id': 's3'};
      expect(isValid(_draft([section])), isFalse);
    });

    test('requires source pages for proposal text', () {
      expect(isValid(_draft([_section(sourcePages: [])])), isFalse);
      expect(
        isValid(_draft([_section(sourcePages: [], source: 'proposal')])),
        isFalse,
      );
    });

    test('allows no source pages for template text', () {
      expect(
        isValid(_draft([_section(sourcePages: [], source: 'template')])),
        isTrue,
      );
    });

    test('rejects a page number below 1', () {
      expect(
        isValid(
          _draft([
            _section(sourcePages: [0]),
          ]),
        ),
        isFalse,
      );
    });
  });

  group('rule_report.schema.json', () {
    final schema = _load(_ruleReportSchemaPath);
    bool isValid(Object? json) => schema.validate(json).isValid;

    test('accepts the three statuses', () {
      expect(
        isValid(
          _report([
            _item('ok'),
            _item('missing', fixHint: 'Add ethics committee name + phone'),
            _item('uncertain', fixHint: 'Check the phone number'),
          ]),
        ),
        isTrue,
      );
    });

    test('requires a fix hint when the element is not ok', () {
      expect(isValid(_report([_item('missing')])), isFalse);
      expect(isValid(_report([_item('uncertain')])), isFalse);
    });

    test('rejects an unknown status', () {
      expect(isValid(_report([_item('present')])), isFalse);
    });

    test('rejects a section_id link', () {
      final item = {..._item('ok'), 'section_id': 's3'};
      expect(isValid(_report([item])), isFalse);
    });
  });
}
