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

/// The proposal PDF is password-protected, so its text can't be read.
final class EncryptedPdfException extends ConsentAiException {
  const EncryptedPdfException(super.message);
}

/// The proposal PDF has no text layer, for example a scanned document.
final class ScannedPdfException extends ConsentAiException {
  const ScannedPdfException(super.message);
}

/// The proposal file is not a readable PDF.
final class CorruptedPdfException extends ConsentAiException {
  const CorruptedPdfException(super.message);
}
