import 'generated_consent_draft.dart';
import 'rule_report.dart';

/// The drafting steps, in the order shown on the drafting screen (04.2).
enum DraftingStep {
  readingPages,
  purposeAndProcedures,
  risksBenefitsAndCompensation,
  checkingRequiredElements,
  simplifyingLanguage,
  applyingTemplate,
}

/// A progress or completion event emitted while drafting.
sealed class DraftingEvent {
  const DraftingEvent();
}

final class DraftingStepStarted extends DraftingEvent {
  const DraftingStepStarted(this.step);

  final DraftingStep step;

  @override
  bool operator ==(Object other) =>
      other is DraftingStepStarted && other.step == step;

  @override
  int get hashCode => Object.hash(DraftingStepStarted, step);
}

final class DraftingStepCompleted extends DraftingEvent {
  const DraftingStepCompleted(this.step);

  final DraftingStep step;

  @override
  bool operator ==(Object other) =>
      other is DraftingStepCompleted && other.step == step;

  @override
  int get hashCode => Object.hash(DraftingStepCompleted, step);
}

/// The last event of a successful drafting.
final class DraftingCompleted extends DraftingEvent {
  const DraftingCompleted({required this.draft, required this.report});

  final GeneratedConsentDraft draft;
  final RuleReport report;

  @override
  bool operator ==(Object other) =>
      other is DraftingCompleted &&
      other.draft == draft &&
      other.report == report;

  @override
  int get hashCode => Object.hash(draft, report);
}
