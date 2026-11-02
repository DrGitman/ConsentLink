import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drafting/consent_drafting_service.dart';
import 'drafting/fake_consent_drafting_service.dart';
import 'llm/guarded_llm_runtime.dart';
import 'llm/llama_cpp_runtime.dart';
import 'llm/llm_runtime.dart';
import 'pdf/pdfrx_text_extractor.dart';
import 'pdf/proposal_text_extractor.dart';
import 'tts/flutter_tts_engine.dart';
import 'tts/read_aloud_service.dart';

/// The drafting service. Returns the fake until the on-device model is ready.
final consentDraftingServiceProvider = Provider<ConsentDraftingService>(
  (ref) => const FakeConsentDraftingService(),
);

/// Reads the text of an accepted proposal PDF, on the device only.
final proposalTextExtractorProvider = Provider<ProposalTextExtractor>(
  (ref) => const PdfrxTextExtractor(),
);

/// Reads consent texts aloud: recording, else a local device voice, else none.
final readAloudServiceProvider = Provider<ReadAloudService>(
  (ref) => ReadAloudService(FlutterTtsEngine()),
);

/// The on-device model; disposed with the provider.
final llmRuntimeProvider = Provider<LlmRuntime>((ref) {
  final runtime = GuardedLlmRuntime(LlamaCppRuntime());
  ref.onDispose(runtime.dispose);
  return runtime;
});
