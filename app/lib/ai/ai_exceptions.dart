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

/// The model file is not on the device.
final class ModelNotFoundException extends ConsentAiException {
  const ModelNotFoundException(super.message);
}

/// The on-device model failed to load or to generate.
final class LlmException extends ConsentAiException {
  const LlmException(super.message);
}
