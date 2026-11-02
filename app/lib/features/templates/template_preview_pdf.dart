import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import 'template_data.dart';

/// Template rules read from assistant checklist items (05.4).
class TemplateLayout {
  const TemplateLayout({
    this.font = 'Arial',
    this.fontSize = 11,
    this.marginCm = 2.5,
    this.footer = 'Page numbers',
    this.columns = const ['English'],
    this.witness = false,
    this.thumbprint = false,
    this.logo = false,
    this.notes = const [],
  });
  final String font;
  final double fontSize;
  final double marginCm;
  final String footer;
  final List<String> columns;
  final bool witness;
  final bool thumbprint;
  final bool logo;
  final List<String> notes;

  factory TemplateLayout.fromItems(List<String> items) {
    var font = 'Arial';
    var size = 11.0;
    var margin = 2.5;
    var footer = 'Page numbers';
    var columns = const ['English'];
    var witness = false, thumb = false, logo = false;
    final notes = <String>[];
    for (final item in items) {
      final lower = item.toLowerCase();
      final f = RegExp(r'([A-Za-z]+)\s+(\d{1,2})\s*pt').firstMatch(item);
      final m = RegExp(r'(\d+(?:\.\d+)?)\s*cm').firstMatch(item);
      if (f != null) {
        font = f.group(1)!;
        size = double.parse(f.group(2)!);
      }
      if (m != null) margin = double.parse(m.group(1)!);
      if (lower.startsWith('footer')) {
        footer = lower.contains('ethics') || lower.contains('rec')
            ? 'REC no. + page'
            : 'Page numbers';
      } else if (lower.contains('column')) {
        final after = item.contains(':') ? item.split(':').last : item;
        columns = [for (final c in after.split('|')) c.trim()]
          ..removeWhere((c) => c.isEmpty);
      } else if (lower.contains('witness')) {
        witness = true;
      } else if (lower.contains('thumb')) {
        thumb = true;
      } else if (lower.contains('logo')) {
        logo = true;
      } else if (f == null && m == null && !lower.startsWith('keeps')) {
        notes.add(item);
      }
    }
    return TemplateLayout(
      font: font,
      fontSize: size,
      marginCm: margin,
      footer: footer,
      columns: columns,
      witness: witness,
      thumbprint: thumb,
      logo: logo,
      notes: notes,
    );
  }

  List<TemplateRule> get rules => [
    TemplateRule(
      key: 'font',
      title: 'Font',
      value: '$font ${fontSize.round()} pt',
      icon: 'form/type',
    ),
    TemplateRule(
      key: 'margins',
      title: 'Margins',
      value: '${marginCm.toStringAsFixed(marginCm % 1 == 0 ? 0 : 1)} cm',
      icon: 'layers',
    ),
    TemplateRule(
      key: 'footer',
      title: 'Footer',
      value: footer,
      icon: 'responses/file',
    ),
    TemplateRule(
      key: 'languages',
      title: 'Languages',
      value: columns.length < 2 ? 'EN' : columns.map(_short).join(' | '),
      icon: 'form/globe',
    ),
    if (witness)
      const TemplateRule(
        key: 'witness',
        title: 'Witness block',
        value: 'Name, signature & date',
        icon: 'form/sign',
      ),
    if (thumbprint)
      const TemplateRule(
        key: 'thumbprint',
        title: 'Thumbprint',
        value: 'Box next to the signature',
        icon: 'form/fingerprint',
      ),
    if (logo)
      const TemplateRule(
        key: 'logo',
        title: 'Logo',
        value: 'Institution logo at the top',
        icon: 'form/image',
      ),
    for (final (i, n) in notes.indexed)
      TemplateRule(
        key: 'note_$i',
        title: 'Note',
        value: n,
        icon: 'form/paragraph',
      ),
  ];

  static String _short(String name) => name.length <= 2
      ? name.toUpperCase()
      : name.substring(0, 2).toUpperCase();
}

/// A one page sample of the form with these rules, for "Preview PDF".
Future<Uint8List> templatePreviewPdf(TemplateLayout layout) async {
  final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Inter-SemiBold.ttf');
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    ),
  );
  final margin = layout.marginCm * PdfPageFormat.cm;
  final body = pw.TextStyle(fontSize: layout.fontSize);
  pw.Widget column(String language, {required bool sample}) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        language,
        style: pw.TextStyle(
          fontSize: layout.fontSize,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 6),
      for (final s in baseSections.where((s) => s.included).take(5)) ...[
        pw.Text(
          s.title,
          style: pw.TextStyle(
            fontSize: layout.fontSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          sample ? s.text : '($language text from the reviewed language pack)',
          style: body,
        ),
        pw.SizedBox(height: 6),
      ],
    ],
  );
  pw.Widget line(String label) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(width: 150, child: pw.Text(label, style: body)),
        pw.Expanded(child: pw.Container(height: .8, color: PdfColors.grey700)),
      ],
    ),
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: margin,
        marginRight: margin,
        marginTop: margin,
        marginBottom: margin,
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (layout.logo)
            pw.Container(
              width: 90,
              height: 36,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500),
              ),
              child: pw.Text(
                'LOGO',
                style: const pw.TextStyle(color: PdfColors.grey600),
              ),
            ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Participant consent form',
            style: pw.TextStyle(
              fontSize: layout.fontSize + 6,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: layout.columns.length < 2
                ? column(layout.columns.first, sample: true)
                : pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      for (final (i, c) in layout.columns.indexed) ...[
                        if (i > 0) pw.SizedBox(width: 14),
                        pw.Expanded(child: column(c, sample: i == 0)),
                      ],
                    ],
                  ),
          ),
          line('Participant signature'),
          if (layout.thumbprint)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10),
              child: pw.Container(
                width: 70,
                height: 70,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Thumbprint',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ),
          if (layout.witness) ...[
            line('Witness name'),
            line('Witness signature'),
          ],
          line('Date'),
          pw.SizedBox(height: 16),
          pw.Text(
            layout.footer == 'REC no. + page'
                ? 'HREC ref: {ethics_no} · Page 1 of 1'
                : 'Page 1 of 1',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Shows [bytes] full screen.
Future<void> showPdfPreview(
  BuildContext context,
  Uint8List bytes,
  String title,
) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfViewer.data(bytes, sourceName: '$title.pdf'),
    ),
  ),
);
