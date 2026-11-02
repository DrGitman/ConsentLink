import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/domain/drafting_event.dart';
import 'package:consentlink/ai/domain/generated_consent_draft.dart';
import 'package:consentlink/ai/domain/generated_section.dart';
import 'package:consentlink/ai/rules/rule_checker.dart';
import 'package:consentlink/ai/service/contract_mapping.dart';
import 'package:consentlink/contracts/consent_ai_service.dart';
import 'package:consentlink/contracts/models.dart' show Confidence;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every step to the contract step of the same name', () {
    for (final step in DraftingStep.values) {
      final started = toContractEvent(DraftingStepStarted(step));
      final completed = toContractEvent(DraftingStepCompleted(step));

      expect((started as AiStepStarted).step.name, step.name);
      expect((completed as AiStepCompleted).step.name, step.name);
    }
  });

  test('maps the result with snake_case keys', () {
    final section = GeneratedSection(
      element: ConsentElement.voluntaryWithdrawal,
      title: 'Your choice',
      text: 'Invented text. You can stop at any time.',
      sourcePages: const [4],
      sourceQuote: 'Invented quote.',
      changes: const ['Used shorter sentences'],
      confidence: Confidence.medium,
    );
    final draft = GeneratedConsentDraft(
      formLanguage: 'en',
      readingGrade: 5.5,
      sections: [section],
      missing: const [ConsentElement.risks, ConsentElement.contactsEthics],
    );
    final completed = DraftingCompleted(
      draft: draft,
      report: checkRules(
        draft,
        StudyProfile.standard,
        failed: const {ConsentElement.risks},
      ),
      failed: const [ConsentElement.risks],
    );

    final result = (toContractEvent(completed) as AiDraftCompleted).result;

    expect(result.formLanguage, 'en');
    expect(result.readingGrade, 5.5);
    final mapped = result.sections.single;
    expect(mapped.elementKey, 'voluntary_withdrawal');
    expect((mapped.title, mapped.text), (section.title, section.text));
    expect(mapped.sourcePages, [4]);
    expect(mapped.sourceQuote, 'Invented quote.');
    expect(mapped.changes, ['Used shorter sentences']);
    expect(mapped.confidence, Confidence.medium);
    expect(result.missing, ['risks', 'contacts_ethics']);
    expect(result.failed, ['risks']);
    expect(result.rules, hasLength(10));
    final risks = result.rules.singleWhere((r) => r.elementKey == 'risks');
    expect(risks.status, AiRuleStatus.uncertain);
    expect(risks.fixHint, modelFailedHint);
  });

  test('maps each AI error to its contract failure', () {
    final cases = <ConsentAiException, AiDraftingFailure>{
      const ModelNotFoundException('m'): AiDraftingFailure.modelUnavailable,
      const EncryptedPdfException('m'): AiDraftingFailure.encryptedPdf,
      const ScannedPdfException('m'): AiDraftingFailure.scannedPdf,
      const CorruptedPdfException('m'): AiDraftingFailure.corruptedPdf,
      const InvalidDraftingRequestException('m'):
          AiDraftingFailure.corruptedPdf,
      const ProposalTooLargeException('m'): AiDraftingFailure.proposalTooLarge,
      const TooManyPagesException('m'): AiDraftingFailure.tooManyPages,
      const LlmException('m'): AiDraftingFailure.modelFailed,
      const InvalidModelOutputException('m'): AiDraftingFailure.modelFailed,
    };
    for (final MapEntry(key: error, value: failure) in cases.entries) {
      final mapped = toContractException(error);
      expect(mapped.failure, failure, reason: '$error');
      expect(mapped.message, 'm');
    }
  });
}
