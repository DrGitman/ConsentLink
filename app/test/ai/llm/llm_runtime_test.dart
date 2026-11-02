import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/llm/gemma_prompt.dart';
import 'package:consentlink/ai/llm/llama_cpp_runtime.dart';
import 'package:consentlink/ai/llm/llm_model_config.dart';
import 'package:consentlink/ai/llm/llm_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds the Gemma 4 prompt with its turn markers', () {
    expect(
      renderGemmaPrompt(system: 'Be brief.', user: 'Hi'),
      '<|turn>system\nBe brief.<turn|>\n<|turn>user\nHi<turn|>\n<|turn>model\n',
    );
  });

  group('inputs are checked', () {
    test('model config', () {
      expect(() => LlmModelConfig(modelPath: ' '), throwsArgumentError);
      expect(
        () => LlmModelConfig(modelPath: 'm.gguf', contextSize: 0),
        throwsRangeError,
      );
      expect(
        () => LlmModelConfig(modelPath: 'm.gguf', threadCount: 0),
        throwsRangeError,
      );
    });

    test('prompt', () {
      expect(
        () => LlmPrompt(system: ' ', user: 'u', maxTokens: 1),
        throwsArgumentError,
      );
      expect(
        () => LlmPrompt(system: 's', user: ' ', maxTokens: 1),
        throwsArgumentError,
      );
      expect(
        () => LlmPrompt(system: 's', user: 'u', maxTokens: 0),
        throwsRangeError,
      );
    });
  });

  group('LlamaCppRuntime without the native library', () {
    test('a missing model file is reported before loading', () {
      expect(
        LlamaCppRuntime().load(
          LlmModelConfig(modelPath: '/models/invented.gguf'),
        ),
        throwsA(isA<ModelNotFoundException>()),
      );
    });

    test('generating before loading is an error', () {
      final prompt = LlmPrompt(system: 's', user: 'u', maxTokens: 1);
      expect(
        LlamaCppRuntime().generate(prompt).toList(),
        throwsA(isA<LlmException>()),
      );
    });
  });
}
