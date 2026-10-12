// contracts/consent_repository.dart
import 'models.dart';

abstract class ConsentRepository {
  /// The id is a UUID generated on the device (works offline).
  /// Must reject the draft if its formVersion/formHash does not match a
  /// published version of that study.
  /// Implementation must write an AuditAction.consentSigned entry.
  Future<Consent> saveConsent(ConsentDraft draft);
  Future<Consent?> getConsent(String id);
  Future<List<Consent>> listByStudy(String studyId);

  /// Sets withdrawn_at. Implementation must write an
  /// AuditAction.consentWithdrawn entry. Never deletes the consent.
  Future<void> withdraw(String consentId, String reason);

  Stream<SyncStatus> watchSyncStatus();
}
