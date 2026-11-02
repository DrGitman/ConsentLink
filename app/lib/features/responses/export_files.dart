import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../contracts/languages.dart';
import '../../contracts/models.dart' as m;
import '../../core/data/data_revision.dart';
import '../../data/export/consent_export_service.dart';
import '../../data/repositories/repository_providers.dart';
import 'responses_data.dart';

/// Where an export landed: the file and a short place to show the user.
class SavedExport {
  const SavedExport(this.file, this.place);
  final File file;
  final String place;
  String get name => file.uri.pathSegments.last;
}

/// Writes [records] as [format]. One record gives one file; several are
/// zipped. Every consent exported is logged in the audit trail.
///
/// With a [password], each PDF is locked with it (any PDF reader asks for
/// it), and Word and CSV files go into an AES encrypted zip (opens in 7-Zip,
/// WinRAR or the Files app on most phones).
Future<SavedExport> exportRecords(
  WidgetRef ref,
  ExportFormat format,
  List<ConsentResponse> records, {
  String? password,
}) async {
  final live = [
    for (final r in records)
      if (r.consentId != null) r,
  ];
  if (live.isEmpty) throw StateError('There are no saved records to export.');
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';

  final files = <(String, Uint8List)>[];
  switch (format) {
    case ExportFormat.pdf:
      final service = await ref.read(exportServiceProvider.future);
      for (final r in live) {
        files.add((
          '${r.code}.pdf',
          password == null
              ? await service.consentPdf(r.consentId!)
              : await service.consentPdfProtected(r.consentId!, password),
        ));
      }
    case ExportFormat.csv:
      final service = await ref.read(exportServiceProvider.future);
      final ids = {for (final r in live) r.consentId!};
      final studies = {for (final r in live) r.studyId!};
      String? header;
      final rows = <String>[];
      for (final id in studies) {
        final lines = (await service.analyticsCsv(
          id,
        )).split('\r\n').where((l) => l.isNotEmpty).toList();
        header ??= lines.first;
        rows.addAll(
          lines.skip(1).where((l) => ids.contains(l.split(',').first)),
        );
      }
      final csv = '${[header!, ...rows].join('\r\n')}\r\n';
      files.add(('consents-$stamp.csv', Uint8List.fromList(utf8.encode(csv))));
    case ExportFormat.word:
      for (final r in live) {
        files.add(('${r.code}.docx', await _consentDocx(ref, r.consentId!)));
      }
  }
  ref.read(dataRevisionProvider.notifier).state++;

  // PDFs carry their own lock; anything else is locked inside the zip.
  final lockZip = password != null && format != ExportFormat.pdf;
  final (name, bytes) = files.length == 1 && !lockZip
      ? files.single
      : (
          'ConsentLink-${format.name}-$stamp.zip',
          _zip(files, password: lockZip ? password : null),
        );
  final (dir, place) = await exportFolder();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return SavedExport(file, place);
}

Uint8List _zip(List<(String, Uint8List)> files, {String? password}) {
  final archive = Archive();
  for (final (name, bytes) in files) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder(password: password).encode(archive));
}

/// The phone's Download/ConsentLink folder when the app may write there,
/// else the app's own files folder.
Future<(Directory, String)> exportFolder() async {
  if (Platform.isAndroid) {
    final public = Directory('/storage/emulated/0/Download/ConsentLink');
    try {
      await public.create(recursive: true);
      final probe = File('${public.path}/.write-check');
      await probe.writeAsString('ok');
      await probe.delete();
      return (public, 'Download/ConsentLink');
    } catch (_) {}
    final external = await getExternalStorageDirectory();
    if (external != null) {
      final dir = await Directory(
        '${external.path}/exports',
      ).create(recursive: true);
      return (dir, 'Android/data/…/files/exports');
    }
  }
  final docs = await getApplicationDocumentsDirectory();
  final dir = await Directory('${docs.path}/exports').create(recursive: true);
  return (dir, 'the app\'s exports folder');
}

/// An editable Word copy of one consent: the record details and the form
/// text exactly as shown. Signature images are in the PDF export.
Future<Uint8List> _consentDocx(WidgetRef ref, String consentId) async {
  final consents = await ref.read(consentRepositoryProvider.future);
  final studies = await ref.read(studyRepositoryProvider.future);
  final audit = await ref.read(auditRepositoryProvider.future);
  final c = await consents.getConsent(consentId);
  if (c == null) throw StateError('That record is no longer on this phone.');
  final study = (await studies.listStudies()).firstWhere(
    (s) => s.id == c.studyId,
  );
  final sections = [
    for (final s in await studies.getPublishedSections(study.id))
      if (s.language == c.language) s,
  ]..sort((a, b) => a.order.compareTo(b.order));
  String time(DateTime? t) =>
      t == null ? '—' : '${t.toUtc().toIso8601String().substring(0, 19)} UTC';
  String yesNo(bool? v) => v == null ? '—' : (v ? 'Yes' : 'No');

  final body = <(String, int)>[
    ('Informed consent record', 1),
    (study.title, 0),
    ('Consent: ${c.id}', 0),
    ('Participant: ${c.participantId}', 0),
    ('Language: ${languageName(c.language)}', 0),
    ('Decision: ${c.decision == m.ConsentDecision.yes ? 'Yes' : 'No'}', 0),
    ('Method: ${c.method.name}', 0),
    ('Witness: ${c.witnessName ?? '—'}', 0),
    ('Interpreter: ${c.interpreterName ?? '—'}', 0),
    if (c.guardianConsent != null) ...[
      ('Guardian consent: ${yesNo(c.guardianConsent)}', 0),
      ('Child assent: ${yesNo(c.childAssent)}', 0),
    ],
    ('Signed (device time): ${time(c.signedAt)}', 0),
    ('Received (server time): ${time(c.receivedAt)}', 0),
    ('Withdrawn: ${time(c.withdrawnAt)}', 0),
    if (c.withdrawalReason != null)
      ('Withdrawal reason: ${c.withdrawalReason}', 0),
    ('Form version: ${c.formVersion}', 0),
    ('Form fingerprint (SHA-256): ${c.formHash}', 0),
    ('Consent form as shown', 2),
    for (final s in sections) (s.text, 0),
    ('Signatures', 2),
    (
      'Signature images are kept with the record and included in the PDF export.',
      0,
    ),
  ];
  final bytes = docxOf(body);
  await audit.log(m.AuditAction.consentExported, consentId, study.id);
  return bytes;
}

/// A minimal .docx: one paragraph per entry; level 1 is the title, 2 a
/// heading, 0 body text.
Uint8List docxOf(List<(String, int)> paragraphs) {
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  String para(String text, int level) {
    final size = switch (level) {
      1 => 36,
      2 => 28,
      _ => 22,
    };
    final bold = level > 0 ? '<w:b/>' : '';
    final runs = text
        .split('\n')
        .map(
          (line) =>
              '<w:r><w:rPr>$bold<w:sz w:val="$size"/></w:rPr>'
              '<w:t xml:space="preserve">${esc(line)}</w:t></w:r>',
        )
        .join('<w:r><w:br/></w:r>');
    return '<w:p><w:pPr><w:spacing w:after="${level > 0 ? 160 : 100}"/></w:pPr>$runs</w:p>';
  }

  const head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  final document =
      '$head<w:document xmlns:w="http://schemas.openxmlformats.org/'
      'wordprocessingml/2006/main"><w:body>'
      '${paragraphs.map((p) => para(p.$1, p.$2)).join()}'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" '
      'w:right="1134" w:bottom="1134" w:left="1134" w:header="708" '
      'w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>';
  const types =
      '$head<Types xmlns="http://schemas.openxmlformats.org/package/'
      '2006/content-types"><Default Extension="rels" ContentType="application/'
      'vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" '
      'ContentType="application/xml"/><Override PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.'
      'wordprocessingml.document.main+xml"/></Types>';
  const rels =
      '$head<Relationships xmlns="http://schemas.openxmlformats.org/'
      'package/2006/relationships"><Relationship Id="rId1" Type="http://'
      'schemas.openxmlformats.org/officeDocument/2006/relationships/'
      'officeDocument" Target="word/document.xml"/></Relationships>';
  return _zip([
    ('[Content_Types].xml', Uint8List.fromList(utf8.encode(types))),
    ('_rels/.rels', Uint8List.fromList(utf8.encode(rels))),
    ('word/document.xml', Uint8List.fromList(utf8.encode(document))),
  ]);
}

/// The blank form as an editable Word file: every published language, with
/// lines to sign by hand.
Future<SavedExport> exportBlankFormWord(WidgetRef ref, String studyId) async {
  final studies = await ref.read(studyRepositoryProvider.future);
  final study = (await studies.listStudies()).firstWhere(
    (s) => s.id == studyId,
  );
  final sections = await studies.getPublishedSections(studyId);
  if (sections.isEmpty) {
    throw StateError('Publish the consent form first, then export it.');
  }
  final byLanguage = <String, List<m.ConsentSection>>{};
  for (final s in sections) {
    byLanguage.putIfAbsent(s.language, () => []).add(s);
  }
  final body = <(String, int)>[];
  for (final entry in byLanguage.entries) {
    final list = entry.value..sort((a, b) => a.order.compareTo(b.order));
    body
      ..add((study.title, 1))
      ..add(('Participant consent form · ${languageName(entry.key)}', 0))
      ..addAll([for (final s in list) (s.text, 0)])
      ..addAll(const [
        ('Participant code: ______________________________', 0),
        ('Signature or thumbprint: ________________________', 0),
        ('Date: __________________________________________', 0),
        ('Witness (if used): ______________________________', 0),
        ('Researcher: ____________________________________', 0),
      ]);
  }
  final safe = study.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
  final (dir, place) = await exportFolder();
  final file = File(
    '${dir.path}/${safe.isEmpty ? 'Consent form' : safe} (blank).docx',
  );
  await file.writeAsBytes(docxOf(body), flush: true);
  return SavedExport(file, place);
}

/// A printable copy of a study's published form, every language it was
/// published in, with blank lines to sign by hand.
Future<SavedExport> exportBlankForm(WidgetRef ref, String studyId) async {
  final studies = await ref.read(studyRepositoryProvider.future);
  final study = (await studies.listStudies()).firstWhere(
    (s) => s.id == studyId,
  );
  final sections = await studies.getPublishedSections(studyId);
  if (sections.isEmpty) {
    throw StateError('Publish the consent form first, then export it.');
  }
  final byLanguage = <String, List<m.ConsentSection>>{};
  for (final s in sections) {
    byLanguage.putIfAbsent(s.language, () => []).add(s);
  }
  final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Inter-SemiBold.ttf');
  final doc = pw.Document(
    title: study.title,
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    ),
  );
  pw.Widget blank(String label) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(width: 170, child: pw.Text(label)),
        pw.Expanded(child: pw.Container(height: 1, color: PdfColors.grey600)),
      ],
    ),
  );
  for (final entry in byLanguage.entries) {
    final list = entry.value..sort((a, b) => a.order.compareTo(b.order));
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Header(level: 0, text: study.title),
          pw.Text(
            'Participant consent form · ${languageName(entry.key)}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          for (final s in list) pw.Paragraph(text: s.text),
          pw.SizedBox(height: 12),
          blank('Participant code'),
          blank('Signature or thumbprint'),
          blank('Date'),
          blank('Witness (if used)'),
          blank('Researcher'),
        ],
      ),
    );
  }
  final bytes = await doc.save();
  final safe = study.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
  final (dir, place) = await exportFolder();
  final file = File(
    '${dir.path}/${safe.isEmpty ? 'Consent form' : safe} (blank).pdf',
  );
  await file.writeAsBytes(bytes, flush: true);
  return SavedExport(file, place);
}
