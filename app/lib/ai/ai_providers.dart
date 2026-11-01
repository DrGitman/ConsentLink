import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drafting/consent_drafting_service.dart';
import 'drafting/fake_consent_drafting_service.dart';
import 'llm/llama_cpp_runtime.dart';
import 'llm/llm_runtime.dart';

/// The drafting service. Returns the fake until the on-device model is ready.
final consentDraftingServiceProvider = Provider<ConsentDraftingService>(
  (ref) => const FakeConsentDraftingService(),
);

/// The on-device model; disposed with the provider.
final llmRuntimeProvider = Provider<LlmRuntime>((ref) {
  final runtime = LlamaCppRuntime();
  ref.onDispose(runtime.dispose);
  return runtime;
});
