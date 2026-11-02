// Gemma 4 turn markers. llama.cpp b10182 can't render Gemma 4's embedded
// Jinja template, so the prompt is built here (llama_cpp_dart gemma_chat probe).
const _turnStart = '<|turn>';
const _turnEnd = '<turn|>';

/// The raw Gemma 4 prompt for one system and one user message, ending where
/// the model starts its answer.
String renderGemmaPrompt({required String system, required String user}) =>
    '${_turn('system', system)}${_turn('user', user)}${_turnStart}model\n';

String _turn(String role, String content) =>
    '$_turnStart$role\n$content$_turnEnd\n';
