import 'llm_model_config.dart';

/// One request to the model: a system and a user message.
final class LlmPrompt {
  /// Throws an [ArgumentError] for a blank message or [maxTokens] below 1.
  LlmPrompt({
    required this.system,
    required this.user,
    required this.maxTokens,
    this.grammar,
  }) {
    if (system.trim().isEmpty) {
      throw ArgumentError.value(system, 'system', 'Is blank');
    }
    if (user.trim().isEmpty) {
      throw ArgumentError.value(user, 'user', 'Is blank');
    }
    if (maxTokens < 1) {
      throw RangeError.value(maxTokens, 'maxTokens', 'Must be >= 1');
    }
  }

  final String system;
  final String user;
  final int maxTokens;

  /// GBNF grammar that constrains the output, or null for free text.
  final String? grammar;
}

/// The on-device language model. Never calls the network.
abstract interface class LlmRuntime {
  /// Throws a [ModelNotFoundException] or an [LlmException].
  Future<void> load(LlmModelConfig config);

  /// Emits one text piece per generated token, possibly empty while a
  /// character is split across tokens. Errors are [LlmException]s.
  Stream<String> generate(LlmPrompt prompt);

  Future<void> dispose();
}
