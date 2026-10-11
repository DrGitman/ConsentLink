// contracts/participant_repository.dart
import 'dart:typed_data';
import 'models.dart';

abstract class ParticipantRepository {
  Future<Participant> create(ParticipantDraft draft);

  /// Stores a signature / thumbprint / witness mark / verbal recording
  /// against a consent. Saved locally first, uploaded when online.
  Future<void> storeSignature(
    String consentId,
    SignatureKind kind,
    Uint8List data,
  );
}
