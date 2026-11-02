// contracts/consent_ai_service.dart
// On-device consent drafting (P3). Agreed between P1 (UI), P2 (data), P3 (AI).
//
// - The proposal never leaves the phone: no network call, ever.
// - Element keys are the snake_case keys of /schemas (purpose, risks, ...).
// - Sections mirror /schemas/consent_draft.schema.json. P2 turns them into
//   ConsentSection rows when they are saved; the AI never sets ids or status.
import 'dart:typed_data';

import 'models.dart';

/// The drafting steps, in the order shown on the drafting screen (04.2).
enum AiDraftingStep {
  readingPages,
  purposeAndProcedures,
  risksBenefitsAndCompensation,
  checkingRequiredElements,
  simplifyingLanguage,
  applyingTemplate,
}

/// Rule checker verdict for one required element. [uncertain] is shown in
/// amber like [missing], so the researcher checks it.
enum AiRuleStatus { ok, missing, uncertain }

/// Why drafting stopped. The UI picks the message to show.
enum AiDraftingFailure {
  modelUnavailable,
  encryptedPdf,
  scannedPdf,
  corruptedPdf,
  proposalTooLarge,
  tooManyPages,
  modelFailed,
}

class AiDraftingException implements Exception {
  final AiDraftingFailure failure;

  /// For logs only; never contains proposal text.
  final String message;
  const AiDraftingException(this.failure, this.message);

  @override
  String toString() => 'AiDraftingException(${failure.name}): $message';
}

class AiDraftRequest {
  /// Bytes of a file the app already accepted.
  final Uint8List proposalPdf;
  final String fileName;

  /// Adds the 4 elements for minors to the 10 required ones.
  final bool involvesMinors;
  const AiDraftRequest({
    required this.proposalPdf,
    required this.fileName,
    required this.involvesMinors,
  });
}

class AiDraftSection {
  final String elementKey;
  final String title;
  final String text;
  final List<int> sourcePages; // 1-based pages of the proposal
  final String? sourceQuote; // exact text in the proposal ("Why?" sheet)
  final List<String> changes; // what the AI changed, one entry per change
  final Confidence confidence;
  const AiDraftSection({
    required this.elementKey,
    required this.title,
    required this.text,
    required this.sourcePages,
    this.sourceQuote,
    this.changes = const [],
    required this.confidence,
  });
}

class AiRuleItem {
  final String elementKey;
  final AiRuleStatus status;
  final String? fixHint; // set unless status is ok
  const AiRuleItem({
    required this.elementKey,
    required this.status,
    this.fixHint,
  });
}

class AiDraftResult {
  final String formLanguage; // code from languages.dart
  final double? readingGrade; // school grade needed to read the form
  final List<AiDraftSection> sections;

  /// Required elements without a section, including [failed] ones.
  final List<String> missing;

  /// Elements the AI gave no valid answer for: the proposal may still cover
  /// them, so their rule item is uncertain, not missing.
  final List<String> failed;

  /// One item per required element.
  final List<AiRuleItem> rules;
  const AiDraftResult({
    required this.formLanguage,
    this.readingGrade,
    required this.sections,
    this.missing = const [],
    this.failed = const [],
    required this.rules,
  });
}

sealed class AiDraftingEvent {
  const AiDraftingEvent();
}

class AiStepStarted extends AiDraftingEvent {
  final AiDraftingStep step;
  const AiStepStarted(this.step);
}

class AiStepCompleted extends AiDraftingEvent {
  final AiDraftingStep step;
  const AiStepCompleted(this.step);
}

/// The last event of a successful drafting.
class AiDraftCompleted extends AiDraftingEvent {
  final AiDraftResult result;
  const AiDraftCompleted(this.result);
}

abstract class ConsentAiService {
  /// False when the model is not on the phone or the phone has too little
  /// memory. The UI can then explain why drafting is off.
  Future<bool> isAvailable();

  /// Emits each step started and completed, in order, then [AiDraftCompleted].
  /// A failure is an [AiDraftingException] error that ends the stream.
  /// Cancelling the subscription stops drafting after the element in progress.
  Stream<AiDraftingEvent> draftConsent(AiDraftRequest request);
}
