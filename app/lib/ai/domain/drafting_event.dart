import 'package:flutter/foundation.dart';

import 'consent_element.dart';
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
  DraftingCompleted({
    required this.draft,
    required this.report,
    List<ConsentElement> failed = const [],
  }) : failed = List.unmodifiable(failed);

  final GeneratedConsentDraft draft;
  final RuleReport report;

  /// Elements in `draft.missing` because the AI gave no valid answer, not
  /// because the proposal lacks them.
  final List<ConsentElement> failed;

  @override
  bool operator ==(Object other) =>
      other is DraftingCompleted &&
      other.draft == draft &&
      other.report == report &&
      listEquals(other.failed, failed);

  @override
  int get hashCode => Object.hash(draft, report, Object.hashAll(failed));
}
