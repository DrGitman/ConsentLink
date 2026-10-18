import 'dart:convert';
import 'dart:io';

import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:flutter_test/flutter_test.dart';

// Paths are relative to app/, where `flutter test` runs.
const _schemaPaths = [
  '../schemas/consent_draft.schema.json',
  '../schemas/rule_report.schema.json',
];
const _standardCount = 10;
const _minorsCount = 14;

List<String> _schemaElementKeys(String path) {
  final schema = jsonDecode(File(path).readAsStringSync()) as Map;
  final elementKey = schema[r'$defs']['element_key'] as Map;
  return (elementKey['enum'] as List).cast<String>();
}

void main() {
  group('jsonKey', () {
    for (final path in _schemaPaths) {
      test('matches element_key in $path', () {
        expect(
          ConsentElement.values.map((e) => e.jsonKey),
          orderedEquals(_schemaElementKeys(path)),
        );
      });
    }
  });

  group('StudyProfile.fromInvolvesMinors', () {
    test('is standard without minors', () {
      expect(StudyProfile.fromInvolvesMinors(false), StudyProfile.standard);
    });

    test('is minors with minors', () {
      expect(StudyProfile.fromInvolvesMinors(true), StudyProfile.minors);
    });
  });

  group('requiredElementsFor', () {
    test('standard has the 10 core elements', () {
      final elements = requiredElementsFor(StudyProfile.standard);

      expect(elements, hasLength(_standardCount));
      expect(elements, isNot(contains(ConsentElement.childAssent)));
    });

    test('minors has the 10 core elements plus the 4 minors elements', () {
      final standard = requiredElementsFor(StudyProfile.standard);
      final minors = requiredElementsFor(StudyProfile.minors);

      expect(minors, hasLength(_minorsCount));
      expect(minors.take(_standardCount), orderedEquals(standard));
      expect(minors.toSet(), ConsentElement.values.toSet());
    });

    test('returns lists that cannot be modified', () {
      for (final profile in StudyProfile.values) {
        expect(
          () => requiredElementsFor(profile).add(ConsentElement.purpose),
          throwsUnsupportedError,
        );
      }
    });
  });
}
