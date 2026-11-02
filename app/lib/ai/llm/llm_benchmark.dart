import 'llm_model_config.dart';
import 'llm_runtime.dart';

// Invented text; never a real proposal.
const benchmarkSystem = 'You rewrite research text in plain language.';
const benchmarkUser =
    'Rewrite for a Grade 6 reader: Participants will complete a '
    'questionnaire regarding household water access and sanitation.';
const benchmarkMaxTokens = 64;

const _bytesPerMegabyte = 1024 * 1024;
const _microsecondsPerSecond = 1000000;

/// What one benchmark run measured on the device.
final class BenchmarkResult {
  const BenchmarkResult({
    required this.loadTime,
    required this.firstTokenTime,
    required this.generationTime,
    required this.tokenCount,
    required this.rssBeforeBytes,
    required this.rssAfterBytes,
    required this.maxRssBytes,
    required this.sampleText,
  });

  final Duration loadTime;

  /// From the request to the first token, prompt processing included.
  final Duration firstTokenTime;
  final Duration generationTime;
  final int tokenCount;
  final int rssBeforeBytes;
  final int rssAfterBytes;
  final int maxRssBytes;

  /// What the model wrote for the invented benchmark prompt.
  final String sampleText;

  double get tokensPerSecond => generationTime.inMicroseconds == 0
      ? 0
      : tokenCount * _microsecondsPerSecond / generationTime.inMicroseconds;

  /// One line for logs and the model card; holds no generated text.
  String get summary =>
      'load ${loadTime.inMilliseconds} ms · first token '
      '${firstTokenTime.inMilliseconds} ms · $tokenCount tokens · '
      '${tokensPerSecond.toStringAsFixed(1)} tok/s · RSS '
      '${_mb(rssBeforeBytes)} → ${_mb(rssAfterBytes)} MB '
      '(max ${_mb(maxRssBytes)} MB)';

  static String _mb(int bytes) =>
      (bytes / _bytesPerMegabyte).toStringAsFixed(0);
}

/// Loads [config] with [runtime], generates once and measures it.
///
/// [currentRss] and [maxRss] read the process memory, `ProcessInfo` on the
/// phone (decision D4.3). The model is disposed afterwards.
Future<BenchmarkResult> runBenchmark(
  LlmRuntime runtime,
  LlmModelConfig config, {
  required int Function() currentRss,
  required int Function() maxRss,
}) async {
  final rssBefore = currentRss();
  final clock = Stopwatch()..start();
  await runtime.load(config);
  final loadTime = clock.elapsed;
  try {
    final prompt = LlmPrompt(
      system: benchmarkSystem,
      user: benchmarkUser,
      maxTokens: benchmarkMaxTokens,
    );
    clock.reset();
    Duration? firstToken;
    var tokens = 0;
    final text = StringBuffer();
    await for (final piece in runtime.generate(prompt)) {
      firstToken ??= clock.elapsed;
      tokens++;
      text.write(piece);
    }
    return BenchmarkResult(
      loadTime: loadTime,
      firstTokenTime: firstToken ?? clock.elapsed,
      generationTime: clock.elapsed,
      tokenCount: tokens,
      rssBeforeBytes: rssBefore,
      rssAfterBytes: currentRss(),
      maxRssBytes: maxRss(),
      sampleText: text.toString(),
    );
  } finally {
    await runtime.dispose();
  }
}
