import '../ai_exceptions.dart';
import 'llm_model_config.dart';
import 'llm_runtime.dart';

const modelBusyMessage = 'The model is busy.';

/// Wraps an [LlmRuntime] so a load never recycles the model while it is
/// generating, and nothing generates while it loads.
///
/// A phone run stopped with "LlamaEngine disposed" when the benchmark tile
/// reloaded the shared model in the middle of a drafting.
final class GuardedLlmRuntime implements LlmRuntime {
  GuardedLlmRuntime(this._inner);

  final LlmRuntime _inner;
  var _activeGenerations = 0;
  var _loading = false;

  bool get _busy => _loading || _activeGenerations > 0;

  @override
  Future<void> load(LlmModelConfig config) async {
    if (_busy) throw const LlmException(modelBusyMessage);
    _loading = true;
    try {
      await _inner.load(config);
    } finally {
      _loading = false;
    }
  }

  @override
  Stream<String> generate(LlmPrompt prompt) async* {
    if (_loading) throw const LlmException(modelBusyMessage);
    _activeGenerations++;
    try {
      yield* _inner.generate(prompt);
    } finally {
      _activeGenerations--;
    }
  }

  @override
  Future<void> dispose() => _inner.dispose();
}
