import 'package:consentlink/contracts/consent_ai_service.dart';

import '../ai_exceptions.dart';
import '../domain/consent_element.dart';
import '../drafting/consent_drafting_service.dart';
import '../drafting/llm_consent_drafting_service.dart';
import '../llm/llm_model_config.dart';
import '../llm/llm_runtime.dart';
import '../pdf/proposal_text_extractor.dart';
import 'contract_mapping.dart';
import 'device_memory.dart';

/// [ConsentAiService] on the on-device model. The proposal never leaves the
/// phone.
///
/// The model is loaded for each drafting and released at the end, even on
/// failure or cancel, so its ~3 GB go back to the app (decision DS.1).
final class OnDeviceConsentAiService implements ConsentAiService {
  const OnDeviceConsentAiService({
    required this.extractor,
    required this.runtime,
    this.modelPath = deviceModelPath,
    this.totalMemoryBytes = readTotalMemoryBytes,
  });

  final ProposalTextExtractor extractor;
  final LlmRuntime runtime;

  /// Throws a [ModelNotFoundException] when the model is not on the phone.
  final Future<String> Function() modelPath;
  final Future<int?> Function() totalMemoryBytes;

  @override
  Future<bool> isAvailable() async {
    try {
      await modelPath();
    } on ModelNotFoundException {
      return false;
    }
    final memory = await totalMemoryBytes();
    return memory != null && memory >= minimumMemoryBytes;
  }

  @override
  Stream<AiDraftingEvent> draftConsent(AiDraftRequest request) async* {
    try {
      final internalRequest = DraftingRequest(
        fileBytes: request.proposalPdf,
        fileName: request.fileName,
        profile: StudyProfile.fromInvolvesMinors(request.involvesMinors),
      );
      await runtime.load(
        LlmModelConfig(
          modelPath: await modelPath(),
          contextSize: largeContextSize,
        ),
      );
      try {
        final drafting = LlmConsentDraftingService(
          extractor: extractor,
          runtime: runtime,
        ).draft(internalRequest);
        await for (final event in drafting) {
          yield toContractEvent(event);
        }
      } finally {
        await runtime.dispose();
      }
    } on ConsentAiException catch (error) {
      throw toContractException(error);
    }
  }
}
