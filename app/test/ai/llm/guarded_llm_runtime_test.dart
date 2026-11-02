import 'dart:async';

import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/llm/guarded_llm_runtime.dart';
import 'package:consentlink/ai/llm/llm_model_config.dart';
import 'package:consentlink/ai/llm/llm_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads and generates only when the test completes [loaded] / [generated].
final class _SlowRuntime implements LlmRuntime {
  var loaded = Completer<void>();
  final generated = StreamController<String>();
  var loads = 0;

  @override
  Future<void> load(LlmModelConfig config) {
    loads++;
    return loaded.future;
  }

  @override
  Stream<String> generate(LlmPrompt prompt) => generated.stream;

  @override
  Future<void> dispose() async {}
}

final _config = LlmModelConfig(modelPath: '/models/invented.gguf');
final _prompt = LlmPrompt(system: 'Invented.', user: 'Invented.', maxTokens: 8);

Matcher get _busy => throwsA(
  isA<LlmException>().having((e) => e.message, 'message', modelBusyMessage),
);

void main() {
  late _SlowRuntime inner;
  late GuardedLlmRuntime runtime;

  setUp(() {
    inner = _SlowRuntime()..loaded.complete();
    runtime = GuardedLlmRuntime(inner);
  });

  test('refuses to reload while a generation runs', () async {
    final pieces = <String>[];
    final generation = runtime.generate(_prompt).listen(pieces.add);
    inner.generated.add('Hi');
    await pumpEventQueue();

    await expectLater(runtime.load(_config), _busy);
    expect(inner.loads, 0);

    await inner.generated.close();
    await generation.asFuture<void>();
    await runtime.load(_config);
    expect(pieces, ['Hi']);
    expect(inner.loads, 1);
  });

  test('a cancelled generation frees the model', () async {
    final generation = runtime.generate(_prompt).listen((_) {});
    await pumpEventQueue();
    await generation.cancel();

    await runtime.load(_config);
    expect(inner.loads, 1);
  });

  test('refuses to generate or reload while loading', () async {
    inner.loaded = Completer<void>();
    final loading = runtime.load(_config);

    await expectLater(runtime.generate(_prompt).drain<void>(), _busy);
    await expectLater(runtime.load(_config), _busy);

    inner.loaded.complete();
    await loading;
    expect(inner.loads, 1);
  });
}
