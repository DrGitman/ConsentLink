// data/export/consent_export_service.dart
// PDF of one signed consent (for the participant's file or an ethics board)
// and a CSV of a study's consents. Every export is logged as consentExported.
//
// The PDF uses the app's Inter font: it has the click letters (ǀ ǁ ǂ ǃ) that
// Ju|'hoansi and Khoekhoegowab text needs, which the built-in PDF fonts lack.
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../contracts/audit_repository.dart';
import '../../contracts/consent_repository.dart';
import '../../contracts/export_service.dart';
import '../../contracts/languages.dart';
import '../../contracts/models.dart';
import '../../contracts/study_repository.dart';
import '../repositories/drift_consent_repository.dart';
import '../repositories/repository_providers.dart';
import 'pdf_password.dart';

/// Signature, thumbprint, witness and audio files of a consent (#80).
typedef SignatureLoader =
    Future<List<(SignatureKind, Uint8List)>> Function(String consentId);

class ConsentExportService implements ExportService {
  ConsentExportService({
    required this.studies,
    required this.consents,
    required this.audit,
    required this.fonts,
    this.signatures,
  });

  final StudyRepository studies;
  final ConsentRepository consents;
  final AuditRepository audit;

  /// Regular and bold TTF bytes.
  final Future<(ByteData, ByteData)> Function() fonts;
  final SignatureLoader? signatures;

  @override
  Future<Uint8List> consentPdf(String consentId) => _consentPdf(consentId);

  /// The same PDF, locked with [password]: readers ask for it before
  /// showing anything (see pdf_password.dart).
  Future<Uint8List> consentPdfProtected(String consentId, String password) =>
      _consentPdf(consentId, password: password);

  Future<Uint8List> _consentPdf(String consentId, {String? password}) async {
    final consent = await consents.getConsent(consentId);
    if (consent == null) throw StateError('No consent $consentId');
    final study = (await studies.listStudies()).firstWhere(
      (s) => s.id == consent.studyId,
    );
    final sections = (await studies.getPublishedSections(
      study.id,
    )).where((s) => s.language == consent.language).toList();
    final trail = (await audit.forStudy(
      study.id,
    )).where((e) => e.entityId == consentId).toList();
    final images = await signatures?.call(consentId) ?? const [];
    final (regular, bold) = await fonts();

    final doc = pw.Document(
      title: 'Consent $consentId',
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      ),
    );
    String time(DateTime? t) =>
        t == null ? '—' : '${t.toUtc().toIso8601String().substring(0, 19)} UTC';
    String yesNo(bool? v) => v == null ? '—' : (v ? 'Yes' : 'No');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Header(level: 0, text: 'Informed consent record'),
          pw.Text(study.title, style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerCount: 0,
            cellAlignment: pw.Alignment.centerLeft,
            data: [
              ['Consent', consent.id],
              ['Participant', consent.participantId],
              ['Language', languageName(consent.language)],
              [
                'Decision',
                consent.decision == ConsentDecision.yes ? 'Yes' : 'No',
              ],
              ['Method', consent.method.name],
              ['Witness', consent.witnessName ?? '—'],
              ['Interpreter', consent.interpreterName ?? '—'],
              if (consent.guardianConsent != null) ...[
                ['Guardian consent', yesNo(consent.guardianConsent)],
                ['Child assent', yesNo(consent.childAssent)],
              ],
              ['Signed (device time)', time(consent.signedAt)],
              ['Received (server time)', time(consent.receivedAt)],
              ['Withdrawn', time(consent.withdrawnAt)],
              if (consent.withdrawalReason != null)
                ['Withdrawal reason', consent.withdrawalReason!],
              ['Form version', '${consent.formVersion}'],
              ['Form fingerprint (SHA-256)', consent.formHash],
            ],
          ),
          pw.Header(level: 1, text: 'Consent form as shown'),
          for (final s in sections) ...[pw.Paragraph(text: s.text)],
          pw.Header(level: 1, text: 'Signatures'),
          if (images.isEmpty)
            pw.Paragraph(text: 'No signature image on this device.')
          else
            for (final (kind, bytes) in images)
              if (kind != SignatureKind.audio) ...[
                pw.Text(kind.name),
                pw.Image(pw.MemoryImage(bytes), height: 90),
                pw.SizedBox(height: 8),
              ] else
                pw.Paragraph(
                  text: 'Verbal consent recording kept with the record.',
                ),
          pw.Header(level: 1, text: 'Audit trail'),
          pw.TableHelper.fromTextArray(
            headers: ['When', 'What', 'By'],
            data: [
              for (final e in trail)
                [
                  time(e.createdAt),
                  e.action.name,
                  e.actorId.isEmpty ? '—' : e.actorId,
                ],
              [time(DateTime.now()), 'consentExported (this export)', ''],
            ],
          ),
        ],
      ),
    );
    if (password != null) {
      doc.document.encryption = PdfPasswordEncryption(doc.document, password);
    }
    final bytes = await doc.save();
    await audit.log(AuditAction.consentExported, consentId, study.id);
    return bytes;
  }

  @override
  Future<String> analyticsCsv(String studyId) async {
    String cell(Object? v) {
      final s = v?.toString() ?? '';
      return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final rows = [
      [
        'consent_id',
        'participant_id',
        'language',
        'decision',
        'method',
        'signed_at',
        'withdrawn_at',
        'form_version',
        'form_hash',
      ],
      for (final c in await consents.listByStudy(studyId))
        [
          c.id,
          c.participantId,
          c.language,
          c.decision.name,
          c.method.name,
          c.signedAt.toUtc().toIso8601String(),
          c.withdrawnAt?.toUtc().toIso8601String(),
          c.formVersion,
          c.formHash,
        ],
    ];
    // Logged against the study: it covers every consent in it.
    await audit.log(AuditAction.consentExported, studyId, studyId);
    return '${rows.map((r) => r.map(cell).join(',')).join('\r\n')}\r\n';
  }
}

Future<(ByteData, ByteData)> _appFonts() async => (
  await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
  await rootBundle.load('assets/fonts/Inter-SemiBold.ttf'),
);

final exportServiceProvider = FutureProvider<ConsentExportService>(
  (ref) async => ConsentExportService(
    studies: await ref.watch(studyRepositoryProvider.future),
    consents: await ref.watch(consentRepositoryProvider.future),
    audit: await ref.watch(auditRepositoryProvider.future),
    fonts: _appFonts,
    signatures: DriftParticipantRepository(
      await ref.watch(appDatabaseProvider.future),
    ).signatureFiles,
  ),
);
