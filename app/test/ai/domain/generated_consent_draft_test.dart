import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/domain/generated_consent_draft.dart';
import 'package:consentlink/ai/domain/generated_section.dart';
import 'package:consentlink/contracts/models.dart' show Confidence;
import 'package:flutter_test/flutter_test.dart';

// Invented test data; not from a real proposal.
GeneratedSection _section(ConsentElement element) => GeneratedSection(
  element: element,
  title: 'Title',
  text: 'Short plain text.',
  sourcePages: const [1],
  changes: const [],
  confidence: Confidence.medium,
);

GeneratedConsentDraft _draft({
  String formLanguage = 'en',
  double? readingGrade = 6.2,
  List<GeneratedSection>? sections,
  List<ConsentElement> missing = const [ConsentElement.contactsEthics],
}) => GeneratedConsentDraft(
  formLanguage: formLanguage,
  readingGrade: readingGrade,
  sections:
      sections ??
      [_section(ConsentElement.purpose), _section(ConsentElement.risks)],
  missing: missing,
);

void main() {
  group('valid draft', () {
    test('keeps its fields', () {
      final draft = _draft();

      expect(draft.formLanguage, 'en');
      expect(draft.readingGrade, 6.2);
      expect(draft.sections.map((s) => s.element), [
        ConsentElement.purpose,
        ConsentElement.risks,
      ]);
      expect(draft.missing, [ConsentElement.contactsEthics]);
    });

    test('accepts an unmeasured reading grade', () {
      expect(_draft(readingGrade: null).readingGrade, isNull);
    });

    test('accepts no sections', () {
      expect(_draft(sections: const []).sections, isEmpty);
    });

    test('lists cannot be changed', () {
      final draft = _draft();

      expect(() => draft.sections.clear(), throwsUnsupportedError);
      expect(() => draft.missing.clear(), throwsUnsupportedError);
    });

    test('is equal to a draft with the same fields', () {
      expect(_draft(), _draft());
      expect(_draft().hashCode, _draft().hashCode);
      expect(_draft(), isNot(_draft(readingGrade: 7)));
    });
  });

  group('rejects', () {
    test('a blank form language', () {
      expect(() => _draft(formLanguage: ' '), throwsArgumentError);
    });

    test('a negative or infinite reading grade', () {
      expect(() => _draft(readingGrade: -1), throwsRangeError);
      expect(() => _draft(readingGrade: double.nan), throwsRangeError);
      expect(() => _draft(readingGrade: double.infinity), throwsRangeError);
    });

    test('two sections for the same element', () {
      expect(
        () => _draft(
          sections: [
            _section(ConsentElement.risks),
            _section(ConsentElement.risks),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a duplicate missing element', () {
      expect(
        () => _draft(
          missing: const [
            ConsentElement.contactsEthics,
            ConsentElement.contactsEthics,
          ],
        ),
        throwsArgumentError,
      );
    });

    test('an element both drafted and missing', () {
      expect(
        () => _draft(missing: const [ConsentElement.risks]),
        throwsArgumentError,
      );
    });
  });
}
