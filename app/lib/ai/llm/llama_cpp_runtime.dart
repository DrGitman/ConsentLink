import 'dart:developer' show log;
import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../ai_exceptions.dart';
import 'gemma_prompt.dart';
import 'llm_model_config.dart';
import 'llm_runtime.dart';

/// Found by Android in the APK (android/app/libs/llama-cpp-dart.aar).
const _androidLibrary = 'libllama.so';

// Sampling from the Gemma 4 model card.
const _temperature = 1.0;
const _topP = 0.95;
const _topK = 64;

const _logName = 'ai.llm';

// llama_cpp_dart 0.9.0-dev.10 feeds the prompt tokens to the whole sampler
// chain (generator.dart `_prefill`), so a grammar sees <bos> and llama.cpp
// aborts the app. Grammars stay off until the binding is fixed (D5.6).
const _grammarSupported = false;

/// [LlmRuntime] on llama.cpp (llama_cpp_dart), in a worker isolate.
final class LlamaCppRuntime implements LlmRuntime {
  LlamaEngine? _engine;

  @override
  Future<void> load(LlmModelConfig config) async {
    if (!File(config.modelPath).existsSync()) {
      throw const ModelNotFoundException('The model file does not exist.');
    }
    await dispose();
    try {
      _engine = await LlamaEngine.spawn(
        libraryPath: _androidLibrary,
        modelParams: ModelParams(path: config.modelPath, gpuLayers: 0),
        contextParams: ContextParams(
          nCtx: config.contextSize,
          nThreads: config.threadCount,
          nThreadsBatch: config.threadCount,
        ),
      );
    } on Exception catch (error) {
      throw LlmException('The model could not be loaded: $error');
    }
  }

  @override
  Stream<String> generate(LlmPrompt prompt) async* {
    final engine = _engine;
    if (engine == null) throw const LlmException('Load the model first.');
    if (prompt.grammar != null && !_grammarSupported) {
      log('Grammar ignored: not supported by the binding', name: _logName);
    }
    final session = await engine.createSession();
    try {
      final events = session.generate(
        prompt: renderGemmaPrompt(system: prompt.system, user: prompt.user),
        addSpecial: true,
        parseSpecial: true,
        maxTokens: prompt.maxTokens,
        sampler: SamplerParams(
          temperature: _temperature,
          topP: _topP,
          topK: _topK,
          grammar: _grammarSupported
              ? GrammarConfig(grammar: prompt.grammar)
              : GrammarConfig.disabled,
        ),
      );
      await for (final event in events) {
        switch (event) {
          case TokenEvent(:final text):
            yield text;
          case DoneEvent(:final trailingText) when trailingText.isNotEmpty:
            yield trailingText;
          case _:
            break;
        }
      }
    } on Exception catch (error) {
      throw LlmException('Generation failed: $error');
    } finally {
      await session.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
  }
}
