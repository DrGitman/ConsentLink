import 'dart:async';
import 'dart:typed_data';

import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/llm/llm_model_config.dart';
import 'package:consentlink/ai/llm/llm_runtime.dart';
import 'package:consentlink/ai/pdf/proposal_page.dart';
import 'package:consentlink/ai/pdf/proposal_text_extractor.dart';
import 'package:consentlink/ai/prompts/consent_prompt.dart';
import 'package:consentlink/ai/service/device_memory.dart';
import 'package:consentlink/ai/service/on_device_consent_ai_service.dart';
import 'package:consentlink/contracts/consent_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _modelPath = '/models/invented.gguf';

final class _FakeExtractor implements ProposalTextExtractor {
  _FakeExtractor([this.error]);

  final ConsentAiException? error;

  @override
  Future<List<ProposalPage>> extract(Uint8List bytes) async {
    if (error case final error?) throw error;
    return [ProposalPage(pageNumber: 1, text: 'Invented study.')];
  }
}

/// Answers "missing" for every element; records loads and disposals.
final class _FakeRuntime implements LlmRuntime {
  final calls = <String>[];

  @override
  Future<void> load(LlmModelConfig config) async =>
      calls.add('load ${config.modelPath} ${config.contextSize}');

  @override
  Stream<String> generate(LlmPrompt prompt) async* {
    final key = RegExp(r'Element key: (\w+)').firstMatch(prompt.user)![1]!;
    calls.add('generate');
    yield missingAnswerFor(
      ConsentElement.values.singleWhere((e) => e.jsonKey == key),
    );
  }

  @override
  Future<void> dispose() async => calls.add('dispose');
}

AiDraftRequest _request({bool involvesMinors = false, int size = 1}) =>
    AiDraftRequest(
      proposalPdf: Uint8List(size),
      fileName: 'invented.pdf',
      involvesMinors: involvesMinors,
    );

OnDeviceConsentAiService _service(
  _FakeRuntime runtime, {
  ConsentAiException? extractorError,
  bool modelPresent = true,
  int? memory = minimumMemoryBytes,
}) => OnDeviceConsentAiService(
  extractor: _FakeExtractor(extractorError),
  runtime: runtime,
  modelPath: () async => modelPresent
      ? _modelPath
      : throw const ModelNotFoundException('Invented: no model.'),
  totalMemoryBytes: () async => memory,
);

Matcher _failure(AiDraftingFailure failure) => emitsError(
  isA<AiDraftingException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  group('isAvailable', () {
    test('true with the model and enough memory', () async {
      expect(await _service(_FakeRuntime()).isAvailable(), isTrue);
    });

    test(
      'false without the model, or with too little or unknown memory',
      () async {
        for (final service in [
          _service(_FakeRuntime(), modelPresent: false),
          _service(_FakeRuntime(), memory: minimumMemoryBytes - 1),
          _service(_FakeRuntime(), memory: null),
        ]) {
          expect(await service.isAvailable(), isFalse);
        }
      },
    );
  });

  test('loads the model, drafts in contract shape, then releases it', () async {
    final runtime = _FakeRuntime();
    final events = await _service(
      runtime,
    ).draftConsent(_request(involvesMinors: true)).toList();

    expect(events, hasLength(AiDraftingStep.values.length * 2 + 1));
    expect(events.first, isA<AiStepStarted>());
    final result = (events.last as AiDraftCompleted).result;
    expect(result.rules, hasLength(14));
    expect(result.missing, contains('safeguarding_contact'));
    expect(runtime.calls.first, 'load $_modelPath $largeContextSize');
    expect(runtime.calls.last, 'dispose');
  });

  test('a PDF error becomes its failure, and the model is released', () async {
    final runtime = _FakeRuntime();

    await expectLater(
      _service(
        runtime,
        extractorError: const ScannedPdfException('Invented: no text.'),
      ).draftConsent(_request()),
      emitsThrough(_failure(AiDraftingFailure.scannedPdf)),
    );
    expect(runtime.calls.last, 'dispose');
  });

  test('without the model, fails before loading anything', () async {
    final runtime = _FakeRuntime();

    await expectLater(
      _service(runtime, modelPresent: false).draftConsent(_request()),
      _failure(AiDraftingFailure.modelUnavailable),
    );
    expect(runtime.calls, isEmpty);
  });

  test('an empty file is refused before loading anything', () async {
    final runtime = _FakeRuntime();

    await expectLater(
      _service(runtime).draftConsent(_request(size: 0)),
      _failure(AiDraftingFailure.corruptedPdf),
    );
    expect(runtime.calls, isEmpty);
  });

  test('cancelling at the first step releases the model', () async {
    final runtime = _FakeRuntime();
    final cancelled = Completer<void>();
    late final StreamSubscription<AiDraftingEvent> subscription;
    subscription = _service(runtime).draftConsent(_request()).listen((_) {
      subscription.cancel().then(cancelled.complete);
    });
    await cancelled.future;

    expect(runtime.calls, ['load $_modelPath $largeContextSize', 'dispose']);
  });
}
