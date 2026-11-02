import 'dart:typed_data';

import 'package:consentlink/contracts/consent_ai_service.dart';
import 'package:consentlink/fakes/fake_consent_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

AiDraftRequest _request({bool involvesMinors = false}) => AiDraftRequest(
  proposalPdf: Uint8List.fromList(const [1]),
  fileName: 'invented.pdf',
  involvesMinors: involvesMinors,
);

const _service = FakeConsentAiService(stepDelay: Duration.zero);

Future<AiDraftResult> _draft({bool involvesMinors = false}) async {
  final events = await _service
      .draftConsent(_request(involvesMinors: involvesMinors))
      .toList();
  return (events.last as AiDraftCompleted).result;
}

void main() {
  test('emits each step started then completed, then the result', () async {
    final events = await _service.draftConsent(_request()).toList();

    expect(events, hasLength(AiDraftingStep.values.length * 2 + 1));
    for (final (index, step) in AiDraftingStep.values.indexed) {
      expect((events[index * 2] as AiStepStarted).step, step);
      expect((events[index * 2 + 1] as AiStepCompleted).step, step);
    }
    expect(events.last, isA<AiDraftCompleted>());
  });

  test('drafts every core element but one, which is missing', () async {
    final result = await _draft();

    expect(result.rules.map((rule) => rule.elementKey), fakeAiCoreKeys);
    expect(result.sections, hasLength(fakeAiCoreKeys.length - 1));
    expect(result.missing, [fakeAiMissingKey]);
    final missingRule = result.rules.singleWhere(
      (rule) => rule.elementKey == fakeAiMissingKey,
    );
    expect(missingRule.status, AiRuleStatus.missing);
    expect(missingRule.fixHint, isNotNull);
  });

  test('adds the 4 elements for minors', () async {
    final result = await _draft(involvesMinors: true);

    expect(result.rules.map((rule) => rule.elementKey), [
      ...fakeAiCoreKeys,
      ...fakeAiMinorsKeys,
    ]);
  });

  test('reports when it is off, and refuses to draft', () async {
    const service = FakeConsentAiService(available: false);

    expect(await service.isAvailable(), isFalse);
    await expectLater(
      service.draftConsent(_request()),
      emitsError(
        isA<AiDraftingException>().having(
          (error) => error.failure,
          'failure',
          AiDraftingFailure.modelUnavailable,
        ),
      ),
    );
  });

  test('fails with the given failure during the first step', () async {
    const service = FakeConsentAiService(
      stepDelay: Duration.zero,
      failure: AiDraftingFailure.scannedPdf,
    );

    await expectLater(
      service.draftConsent(_request()),
      emitsInOrder([
        isA<AiStepStarted>(),
        emitsError(
          isA<AiDraftingException>().having(
            (error) => error.failure,
            'failure',
            AiDraftingFailure.scannedPdf,
          ),
        ),
      ]),
    );
  });
}
