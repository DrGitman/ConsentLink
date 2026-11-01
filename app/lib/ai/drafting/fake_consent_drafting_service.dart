import '../domain/drafting_event.dart';
import 'consent_drafting_service.dart';
import 'fake_sample_draft.dart';

/// Matches the step duration of the drafting screen preview.
const defaultFakeStepDelay = Duration(milliseconds: 700);

/// Replays the drafting steps, then returns an invented sample draft.
final class FakeConsentDraftingService implements ConsentDraftingService {
  const FakeConsentDraftingService({this.stepDelay = defaultFakeStepDelay});

  final Duration stepDelay;

  @override
  Stream<DraftingEvent> draft(DraftingRequest request) async* {
    for (final step in DraftingStep.values) {
      yield DraftingStepStarted(step);
      await Future<void>.delayed(stepDelay);
      yield DraftingStepCompleted(step);
    }
    final draft = fakeSampleDraftFor(request.profile);
    yield DraftingCompleted(
      draft: draft,
      report: fakeRuleReportFor(draft, request.profile),
    );
  }
}
