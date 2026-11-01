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

/// The language code is not one of `contracts/languages.dart`.
final class UnsupportedLanguageException extends ConsentAiException {
  const UnsupportedLanguageException(super.message);
}

/// The device text-to-speech engine failed to read a text aloud.
final class ReadAloudException extends ConsentAiException {
  const ReadAloudException(super.message);
}
