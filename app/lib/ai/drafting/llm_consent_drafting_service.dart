import 'dart:developer' show log;

import '../ai_exceptions.dart';
import '../domain/consent_element.dart';
import '../domain/drafting_event.dart';
import '../domain/generated_consent_draft.dart';
import '../domain/generated_section.dart';
import '../llm/llm_runtime.dart';
import '../pdf/proposal_page.dart';
import '../pdf/proposal_text_extractor.dart';
import '../prompts/consent_output_parser.dart';
import '../prompts/consent_prompt.dart';
import '../prompts/page_selector.dart';
import '../rules/readability.dart';
import '../rules/rule_checker.dart';
import 'consent_drafting_service.dart';

const _logName = 'ai.drafting';

/// One retry per element (decision D5.4).
const maxAttemptsPerElement = 2;

/// Drafted in [DraftingStep.purposeAndProcedures]; every other element is
/// drafted in [DraftingStep.risksBenefitsAndCompensation].
const purposeAndProceduresElements = {
  ConsentElement.purpose,
  ConsentElement.procedures,
  ConsentElement.duration,
};

/// Drafts a consent form with the on-device model, one call per element
/// (decision D5.5). The proposal never leaves the phone.
///
/// [runtime] must already be loaded (D5.11). Cancelling stops drafting once
/// the element in progress is done.
final class LlmConsentDraftingService implements ConsentDraftingService {
  const LlmConsentDraftingService({
    required this.extractor,
    required this.runtime,
  });

  final ProposalTextExtractor extractor;
  final LlmRuntime runtime;

  @override
  Stream<DraftingEvent> draft(DraftingRequest request) async* {
    yield const DraftingStepStarted(DraftingStep.readingPages);
    final pages = await extractor.extract(request.fileBytes);
    yield const DraftingStepCompleted(DraftingStep.readingPages);

    final required = requiredElementsFor(request.profile);
    final sections = <GeneratedSection>[];
    final failed = <ConsentElement>[];
    for (final (step, inStep) in [
      (DraftingStep.purposeAndProcedures, true),
      (DraftingStep.risksBenefitsAndCompensation, false),
    ]) {
      yield DraftingStepStarted(step);
      for (final element in required) {
        if (purposeAndProceduresElements.contains(element) != inStep) continue;
        final (answer, section) = await _draftElement(element, pages);
        if (section != null) sections.add(section);
        if (answer == _Answer.invalid) failed.add(element);
      }
      yield DraftingStepCompleted(step);
    }

    yield const DraftingStepStarted(DraftingStep.checkingRequiredElements);
    final report = checkRules(
      _draftOf(sections, required),
      request.profile,
      failed: failed.toSet(),
    );
    yield const DraftingStepCompleted(DraftingStep.checkingRequiredElements);

    yield const DraftingStepStarted(DraftingStep.simplifyingLanguage);
    final grade = draftReadingGrade(sections, draftLanguage);
    yield const DraftingStepCompleted(DraftingStep.simplifyingLanguage);

    // No template yet: the step is shown and passes through.
    yield const DraftingStepStarted(DraftingStep.applyingTemplate);
    yield const DraftingStepCompleted(DraftingStep.applyingTemplate);

    yield DraftingCompleted(
      draft: _draftOf(sections, required, readingGrade: grade),
      report: report,
      failed: failed,
    );
  }

  /// The last answer for [element] and its section, if any. [_Answer.invalid]
  /// means both attempts failed. A runtime failure is an [LlmException] and
  /// stops drafting.
  Future<(_Answer, GeneratedSection?)> _draftElement(
    ConsentElement element,
    List<ProposalPage> pages,
  ) async {
    final selected = selectPagesFor(element, pages);
    final prompt = buildSectionPrompt(element, selected);
    final givenPages = {for (final page in selected) page.pageNumber};
    for (var attempt = 1; attempt <= maxAttemptsPerElement; attempt++) {
      final stopwatch = Stopwatch()..start();
      final output = await runtime.generate(prompt).join();
      final (answer, section) = _read(element, output, givenPages);
      log(
        '${element.jsonKey} attempt $attempt: ${answer.name}, '
        '${selected.length} pages, ${stopwatch.elapsedMilliseconds} ms',
        name: _logName,
      );
      if (answer != _Answer.invalid) return (answer, section);
    }
    return (_Answer.invalid, null);
  }
}

enum _Answer { section, missing, invalid }

/// Retry triggers (D5.13): invalid JSON, a dropped section, or a cited page
/// the model was not given (D5.12). A clean "missing" is a valid answer.
(_Answer, GeneratedSection?) _read(
  ConsentElement element,
  String output,
  Set<int> givenPages,
) {
  final ParsedDraft parsed;
  try {
    parsed = parseConsentDraft(output);
  } on InvalidModelOutputException {
    return (_Answer.invalid, null);
  }
  final section = parsed.draft.sections
      .where((section) => section.element == element)
      .firstOrNull;
  if (section == null) {
    final cleanMissing =
        parsed.issues.isEmpty && parsed.draft.missing.contains(element);
    return (cleanMissing ? _Answer.missing : _Answer.invalid, null);
  }
  return section.sourcePages.every(givenPages.contains)
      ? (_Answer.section, section)
      : (_Answer.invalid, null);
}

GeneratedConsentDraft _draftOf(
  List<GeneratedSection> sections,
  List<ConsentElement> required, {
  double? readingGrade,
}) {
  final drafted = {for (final section in sections) section.element};
  return GeneratedConsentDraft(
    formLanguage: draftLanguage,
    readingGrade: readingGrade,
    sections: sections,
    missing: [
      for (final element in required)
        if (!drafted.contains(element)) element,
    ],
  );
}
