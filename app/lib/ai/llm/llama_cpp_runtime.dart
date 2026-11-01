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
          grammar: GrammarConfig(grammar: prompt.grammar),
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
