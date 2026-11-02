import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/domain/drafting_event.dart';
import 'package:consentlink/ai/drafting/fake_sample_draft.dart';
import 'package:consentlink/ai/rules/rule_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final draft = fakeSampleDraftFor(StudyProfile.standard);
  final report = checkRules(draft, StudyProfile.standard);

  group('DraftingCompleted.failed', () {
    test('is empty by default', () {
      expect(DraftingCompleted(draft: draft, report: report).failed, isEmpty);
    });

    test('cannot be changed', () {
      final completed = DraftingCompleted(
        draft: draft,
        report: report,
        failed: [ConsentElement.risks],
      );
      expect(
        () => completed.failed.add(ConsentElement.purpose),
        throwsUnsupportedError,
      );
    });

    test('is part of equality', () {
      DraftingCompleted completed(List<ConsentElement> failed) =>
          DraftingCompleted(draft: draft, report: report, failed: failed);

      expect(
        completed([ConsentElement.risks]),
        completed([ConsentElement.risks]),
      );
      expect(completed([ConsentElement.risks]), isNot(completed(const [])));
    });
  });
}
