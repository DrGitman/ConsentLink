// contracts/consent_repository.dart
import 'models.dart';

abstract class ConsentRepository {
  /// The id is a UUID generated on the device (works offline).
  /// Must reject the draft if its formVersion/formHash does not match a
  /// published version of that study, and must reject a minor's Yes unless
  /// guardianConsent and childAssent are both true (a child's No always wins).
  /// The server enforces the same rules and records AuditAction.consentSigned.
  Future<Consent> saveConsent(ConsentDraft draft);
  Future<Consent?> getConsent(String id);
  Future<List<Consent>> listByStudy(String studyId);

  /// Sets withdrawnAt and withdrawalReason. A withdrawal can never be changed
  /// or undone, and a consent is never deleted. The server records
  /// AuditAction.consentWithdrawn.
  Future<void> withdraw(String consentId, String reason);

  Stream<SyncStatus> watchSyncStatus();
}
