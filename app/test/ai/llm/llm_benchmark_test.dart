import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/llm/llm_benchmark.dart';
import 'package:consentlink/ai/llm/llm_model_config.dart';
import 'package:consentlink/ai/llm/llm_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

const _pieces = ['You ', 'will ', 'answer ', 'questions.'];

final class _FakeRuntime implements LlmRuntime {
  final calls = <String>[];
  LlmPrompt? prompt;

  @override
  Future<void> load(LlmModelConfig config) async =>
      calls.add('load ${config.contextSize}');

  @override
  Stream<String> generate(LlmPrompt prompt) {
    this.prompt = prompt;
    calls.add('generate');
    return Stream.fromIterable(_pieces);
  }

  @override
  Future<void> dispose() async => calls.add('dispose');
}

LlmModelConfig _config({int contextSize = smallContextSize}) => LlmModelConfig(
  modelPath: '/models/invented.gguf',
  contextSize: contextSize,
);

void main() {
  test(
    'loads, generates once and measures, leaving the model loaded',
    () async {
      final runtime = _FakeRuntime();
      var rss = 100;

      final result = await runBenchmark(
        runtime,
        _config(contextSize: largeContextSize),
        currentRss: () => rss += 50,
        maxRss: () => 400,
      );

      expect(runtime.calls, ['load 4096', 'generate']);
      expect(runtime.prompt!.maxTokens, benchmarkMaxTokens);
      expect(result.tokenCount, _pieces.length);
      expect(result.sampleText, _pieces.join());
      expect((result.rssBeforeBytes, result.rssAfterBytes), (150, 200));
      expect(result.maxRssBytes, 400);
    },
  );

  test('computes tokens per second and a summary without text', () {
    const result = BenchmarkResult(
      loadTime: Duration(seconds: 3),
      firstTokenTime: Duration(milliseconds: 900),
      generationTime: Duration(seconds: 8),
      tokenCount: 64,
      rssBeforeBytes: 100 * 1024 * 1024,
      rssAfterBytes: 2100 * 1024 * 1024,
      maxRssBytes: 2200 * 1024 * 1024,
      sampleText: 'Invented answer.',
    );
    expect(result.tokensPerSecond, 8);
    expect(result.summary, contains('8.0 tok/s'));
    expect(result.summary, contains('100 → 2100 MB'));
    expect(result.summary, isNot(contains('Invented')));
  });

  test('a generation failure is rethrown, the model is not disposed', () async {
    final runtime = _FailingRuntime();
    await expectLater(
      runBenchmark(runtime, _config(), currentRss: () => 0, maxRss: () => 0),
      throwsA(isA<LlmException>()),
    );
    expect(runtime.calls, isNot(contains('dispose')));
  });
}

final class _FailingRuntime extends _FakeRuntime {
  @override
  Stream<String> generate(LlmPrompt prompt) =>
      Stream.error(const LlmException('Invented failure.'));
}
