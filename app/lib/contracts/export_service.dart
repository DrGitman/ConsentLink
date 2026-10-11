// contracts/export_service.dart
import 'dart:typed_data';

abstract class ExportService {
  /// Implementation must write an AuditAction.consentExported entry.
  Future<Uint8List> consentPdf(String consentId);
  Future<String> analyticsCsv(String studyId);
}
