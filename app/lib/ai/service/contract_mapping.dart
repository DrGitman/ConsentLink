import 'package:consentlink/contracts/consent_ai_service.dart';

import '../ai_exceptions.dart';
import '../domain/drafting_event.dart';
import '../domain/generated_section.dart';
import '../domain/rule_report.dart';

/// [event] in the shape of `contracts/consent_ai_service.dart`.
AiDraftingEvent toContractEvent(DraftingEvent event) => switch (event) {
  DraftingStepStarted(:final step) => AiStepStarted(_step(step)),
  DraftingStepCompleted(:final step) => AiStepCompleted(_step(step)),
  DraftingCompleted() => AiDraftCompleted(_result(event)),
};

/// The contract failure for [error]; the message never holds proposal text.
AiDraftingException toContractException(ConsentAiException error) =>
    AiDraftingException(switch (error) {
      ModelNotFoundException() => AiDraftingFailure.modelUnavailable,
      EncryptedPdfException() => AiDraftingFailure.encryptedPdf,
      ScannedPdfException() => AiDraftingFailure.scannedPdf,
      CorruptedPdfException() ||
      InvalidDraftingRequestException() => AiDraftingFailure.corruptedPdf,
      ProposalTooLargeException() => AiDraftingFailure.proposalTooLarge,
      TooManyPagesException() => AiDraftingFailure.tooManyPages,
      _ => AiDraftingFailure.modelFailed,
    }, error.message);

AiDraftingStep _step(DraftingStep step) => switch (step) {
  DraftingStep.readingPages => AiDraftingStep.readingPages,
  DraftingStep.purposeAndProcedures => AiDraftingStep.purposeAndProcedures,
  DraftingStep.risksBenefitsAndCompensation =>
    AiDraftingStep.risksBenefitsAndCompensation,
  DraftingStep.checkingRequiredElements =>
    AiDraftingStep.checkingRequiredElements,
  DraftingStep.simplifyingLanguage => AiDraftingStep.simplifyingLanguage,
  DraftingStep.applyingTemplate => AiDraftingStep.applyingTemplate,
};

AiDraftResult _result(DraftingCompleted completed) {
  final draft = completed.draft;
  return AiDraftResult(
    formLanguage: draft.formLanguage,
    readingGrade: draft.readingGrade,
    sections: [for (final section in draft.sections) _section(section)],
    missing: [for (final element in draft.missing) element.jsonKey],
    failed: [for (final element in completed.failed) element.jsonKey],
    rules: [for (final item in completed.report.items) _rule(item)],
  );
}

AiDraftSection _section(GeneratedSection section) => AiDraftSection(
  elementKey: section.element.jsonKey,
  title: section.title,
  text: section.text,
  sourcePages: section.sourcePages,
  sourceQuote: section.sourceQuote,
  changes: section.changes,
  confidence: section.confidence,
);

AiRuleItem _rule(RuleItem item) => AiRuleItem(
  elementKey: item.element.jsonKey,
  status: switch (item.status) {
    RuleStatus.ok => AiRuleStatus.ok,
    RuleStatus.missing => AiRuleStatus.missing,
    RuleStatus.uncertain => AiRuleStatus.uncertain,
  },
  fixHint: item.fixHint,
);
