// fakes/fake_consent_ai_service.dart
// Fake of contracts/consent_ai_service.dart: replays an invented draft.
import '../contracts/consent_ai_service.dart';
import '../contracts/models.dart';

const fakeAiCoreKeys = [
  'purpose',
  'procedures',
  'duration',
  'risks',
  'benefits',
  'compensation',
  'confidentiality',
  'voluntary_withdrawal',
  'contacts_researcher',
  'contacts_ethics',
];

const fakeAiMinorsKeys = [
  'guardian_permission',
  'child_assent',
  'child_dissent_respected',
  'safeguarding_contact',
];

/// Left out of the draft, so the UI can show a missing element.
const fakeAiMissingKey = 'contacts_ethics';
const fakeAiMissingHint = 'Add a section that covers this element.';
const fakeAiReadingGrade = 6.0;

const _formLanguage = 'en';
const _defaultStepDelay = Duration(milliseconds: 700);

class FakeConsentAiService implements ConsentAiService {
  final bool available;
  final Duration stepDelay;

  /// When set, drafting fails with it during the first step.
  final AiDraftingFailure? failure;
  const FakeConsentAiService({
    this.available = true,
    this.stepDelay = _defaultStepDelay,
    this.failure,
  });

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<AiDraftingEvent> draftConsent(AiDraftRequest request) async* {
    if (!available) {
      throw const AiDraftingException(
        AiDraftingFailure.modelUnavailable,
        'Fake: the model is off.',
      );
    }
    for (final step in AiDraftingStep.values) {
      yield AiStepStarted(step);
      await Future<void>.delayed(stepDelay);
      if (failure case final failure?) {
        throw AiDraftingException(failure, 'Fake failure.');
      }
      yield AiStepCompleted(step);
    }
    yield AiDraftCompleted(_result(request.involvesMinors));
  }
}

AiDraftResult _result(bool involvesMinors) {
  final keys = [...fakeAiCoreKeys, if (involvesMinors) ...fakeAiMinorsKeys];
  final drafted = keys.where((key) => key != fakeAiMissingKey);
  return AiDraftResult(
    formLanguage: _formLanguage,
    readingGrade: fakeAiReadingGrade,
    sections: [
      for (final (index, key) in drafted.indexed) _section(key, index),
    ],
    missing: const [fakeAiMissingKey],
    rules: [
      for (final key in keys)
        key == fakeAiMissingKey
            ? AiRuleItem(
                elementKey: key,
                status: AiRuleStatus.missing,
                fixHint: fakeAiMissingHint,
              )
            : AiRuleItem(elementKey: key, status: AiRuleStatus.ok),
    ],
  );
}

// Invented text: no real proposal or participant data.
AiDraftSection _section(String key, int index) => AiDraftSection(
  elementKey: key,
  title: 'About $key',
  text:
      'This is invented text about $key. You can ask us questions at any '
      'time. Taking part is your choice.',
  sourcePages: [index + 1],
  sourceQuote: 'Invented proposal text about $key.',
  changes: const ['Used shorter sentences'],
  confidence: Confidence.high,
);
