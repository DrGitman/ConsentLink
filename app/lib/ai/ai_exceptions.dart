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

/// The proposal file is above the size limit read on the device.
final class ProposalTooLargeException extends ConsentAiException {
  const ProposalTooLargeException(super.message);
}

/// The proposal PDF has more pages than the device reads.
final class TooManyPagesException extends ConsentAiException {
  const TooManyPagesException(super.message);
}

/// The language code is not one of `contracts/languages.dart`.
final class UnsupportedLanguageException extends ConsentAiException {
  const UnsupportedLanguageException(super.message);
}

/// The device text-to-speech engine failed to read a text aloud.
final class ReadAloudException extends ConsentAiException {
  const ReadAloudException(super.message);
}

/// The model file is not on the device.
final class ModelNotFoundException extends ConsentAiException {
  const ModelNotFoundException(super.message);
}

/// The on-device model failed to load or to generate.
final class LlmException extends ConsentAiException {
  const LlmException(super.message);
}

/// Why a model download failed, so the UI can pick its message.
enum ModelDownloadFailure { network, server, storage, checksum }

/// The model could not be downloaded or did not match its checksum.
final class ModelDownloadException extends ConsentAiException {
  const ModelDownloadException(this.failure, super.message);

  final ModelDownloadFailure failure;
}
