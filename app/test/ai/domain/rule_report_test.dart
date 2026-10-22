import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/domain/rule_report.dart';
import 'package:flutter_test/flutter_test.dart';

RuleItem _ok(ConsentElement element) =>
    RuleItem(element: element, status: RuleStatus.ok);

RuleItem _missing(ConsentElement element) => RuleItem(
  element: element,
  status: RuleStatus.missing,
  fixHint: 'Add who to contact about ethics.',
);

void main() {
  group('RuleItem', () {
    test('ok needs no fix hint', () {
      expect(_ok(ConsentElement.purpose).fixHint, isNull);
    });

    test('ok may carry a fix hint', () {
      final item = RuleItem(
        element: ConsentElement.purpose,
        status: RuleStatus.ok,
        fixHint: 'Could be shorter.',
      );

      expect(item.fixHint, 'Could be shorter.');
    });

    test('missing and uncertain need a fix hint', () {
      for (final status in [RuleStatus.missing, RuleStatus.uncertain]) {
        expect(
          () => RuleItem(element: ConsentElement.risks, status: status),
          throwsArgumentError,
        );
      }
    });

    test('rejects a blank fix hint', () {
      expect(
        () => RuleItem(
          element: ConsentElement.risks,
          status: RuleStatus.uncertain,
          fixHint: '  ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('RuleReport', () {
    test('derives found and required from its items', () {
      final elements = requiredElementsFor(StudyProfile.standard);
      final report = RuleReport(
        items: [
          for (final element in elements)
            element == ConsentElement.contactsEthics
                ? _missing(element)
                : _ok(element),
        ],
      );

      expect(report.found, 9);
      expect(report.required, 10);
    });

    test('counts uncertain items as not found', () {
      final report = RuleReport(
        items: [
          _ok(ConsentElement.purpose),
          RuleItem(
            element: ConsentElement.confidentiality,
            status: RuleStatus.uncertain,
            fixHint: 'Say how long the data is kept.',
          ),
        ],
      );

      expect(report.found, 1);
      expect(report.required, 2);
    });

    test('items cannot be changed', () {
      final report = RuleReport(items: [_ok(ConsentElement.purpose)]);

      expect(() => report.items.clear(), throwsUnsupportedError);
    });

    test('is equal to a report with the same items', () {
      RuleReport report() => RuleReport(items: [_ok(ConsentElement.purpose)]);

      expect(report(), report());
      expect(report().hashCode, report().hashCode);
      expect(
        report(),
        isNot(RuleReport(items: [_missing(ConsentElement.purpose)])),
      );
    });

    test('rejects no items', () {
      expect(() => RuleReport(items: const []), throwsArgumentError);
    });

    test('rejects two items for the same element', () {
      expect(
        () => RuleReport(
          items: [_ok(ConsentElement.risks), _missing(ConsentElement.risks)],
        ),
        throwsArgumentError,
      );
    });
  });
}
