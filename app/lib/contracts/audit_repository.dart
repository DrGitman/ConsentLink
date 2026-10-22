// contracts/audit_repository.dart
import 'models.dart';

/// Append-only. There is deliberately no update or delete method.
/// The server writes every entry itself except AuditAction.consentExported,
/// so log() is only for exports. Other actions are rejected on sync.
abstract class AuditRepository {
  Future<void> log(AuditAction action, String entityId, String studyId);
  Future<List<AuditEntry>> forStudy(String studyId);
}
