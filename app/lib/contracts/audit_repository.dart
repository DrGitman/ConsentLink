// contracts/audit_repository.dart
import 'models.dart';

/// Append-only. There is deliberately no update or delete method.
abstract class AuditRepository {
  Future<void> log(AuditAction action, String entityId, String studyId);
  Future<List<AuditEntry>> forStudy(String studyId);
}
