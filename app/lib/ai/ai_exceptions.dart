/// Base class for every error raised by the AI module.
class ConsentAiException implements Exception {
  const ConsentAiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A drafting request was rejected before any work started.
final class InvalidDraftingRequestException extends ConsentAiException {
  const InvalidDraftingRequestException(super.message);
}

/// The model's output can't be read as a consent draft.
///
/// [message] names the problem, never the form text.
final class InvalidModelOutputException extends ConsentAiException {
  const InvalidModelOutputException(super.message);
}
