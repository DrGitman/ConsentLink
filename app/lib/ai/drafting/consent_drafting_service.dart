import 'dart:typed_data';

import '../ai_exceptions.dart';
import '../domain/consent_element.dart';
import '../domain/drafting_event.dart';

/// The input of drafting: a proposal file that has already been accepted.
final class DraftingRequest {
  /// Throws an [InvalidDraftingRequestException] for an empty file or name.
  DraftingRequest({
    required this.fileBytes,
    required this.fileName,
    required this.profile,
  }) {
    if (fileBytes.isEmpty) {
      throw const InvalidDraftingRequestException(
        'The proposal file is empty.',
      );
    }
    if (fileName.trim().isEmpty) {
      throw const InvalidDraftingRequestException(
        'The proposal file has no name.',
      );
    }
  }

  final Uint8List fileBytes;
  final String fileName;
  final StudyProfile profile;
}

/// Drafts a consent form from a research proposal, on the device only.
abstract interface class ConsentDraftingService {
  /// Emits a start and a completion event for each [DraftingStep], in order,
  /// then exactly one [DraftingCompleted]. Failures are [ConsentAiException]
  /// errors on the stream. Cancelling the subscription stops drafting.
  Stream<DraftingEvent> draft(DraftingRequest request);
}
