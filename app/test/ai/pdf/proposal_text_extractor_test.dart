import 'dart:typed_data';

import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/pdf/pdfrx_text_extractor.dart';
import 'package:consentlink/ai/pdf/proposal_file_guard.dart';
import 'package:consentlink/ai/pdf/proposal_page.dart';
import 'package:consentlink/ai/pdf/proposal_text_extractor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

// Invented proposal text; not from a real study.
const _pageTexts = [
  'This study looks at how families get clean water in the north.',
  'Each interview takes about forty minutes and can stop at any time.',
];

Future<Uint8List> _pdf(List<pw.Widget> pages) async {
  final document = pw.Document();
  for (final page in pages) {
    document.addPage(pw.Page(build: (_) => page));
  }
  return document.save();
}

ProposalPage _page(int number, String text) =>
    ProposalPage(pageNumber: number, text: text);

void main() {
  group('requireTextLayer', () {
    test('keeps every page when one has real text', () {
      final pages = [_page(1, ''), _page(2, _pageTexts.first)];
      expect(requireTextLayer(pages), pages);
    });

    test('throws when no page reaches $minCharsForTextPage characters', () {
      final pages = [_page(1, 'Figure 1'), _page(2, ' \n\t ')];
      expect(
        () => requireTextLayer(pages),
        throwsA(isA<ScannedPdfException>()),
      );
    });

    test('does not count whitespace', () {
      final spaced = 'a b c d e f g h i j k l m n o p q r s';
      expect(
        () => requireTextLayer([_page(1, spaced)]),
        throwsA(isA<ScannedPdfException>()),
      );
    });
  });

  test('a page number starts at 1', () {
    expect(() => _page(0, 'text'), throwsRangeError);
  });

  group('PdfrxTextExtractor on PDFium', () {
    // Host tests download PDFium once into the temp folder.
    const extractor = PdfrxTextExtractor(initialize: pdfrxInitialize);

    test('reads the text page by page', () async {
      final bytes = await _pdf([for (final text in _pageTexts) pw.Text(text)]);

      final pages = await extractor.extract(bytes);

      expect(pages.map((page) => page.pageNumber), [1, 2]);
      expect(pages.first.text, contains('clean water'));
      expect(pages.last.text, contains('forty minutes'));
    });

    test('a PDF with only shapes is a scanned PDF', () async {
      final bytes = await _pdf([pw.Container(width: 200, height: 200)]);
      expect(extractor.extract(bytes), throwsA(isA<ScannedPdfException>()));
    });

    test('a truncated PDF is corrupted', () async {
      final bytes = await _pdf([pw.Text(_pageTexts.first)]);
      final truncated = Uint8List.sublistView(bytes, 0, bytes.length ~/ 3);
      expect(
        extractor.extract(truncated),
        throwsA(isA<CorruptedPdfException>()),
      );
    });

    test('bytes that are not a PDF are corrupted', () {
      final notPdf = Uint8List.fromList('Not a PDF at all'.codeUnits);
      expect(extractor.extract(notPdf), throwsA(isA<CorruptedPdfException>()));
    });

    test('an empty file is corrupted', () {
      expect(
        extractor.extract(Uint8List(0)),
        throwsA(isA<CorruptedPdfException>()),
      );
    });

    test('a PDF above $maxProposalPages pages is refused', () async {
      final bytes = await _pdf([
        for (var i = 0; i <= maxProposalPages; i++) pw.Text(_pageTexts.first),
      ]);
      expect(extractor.extract(bytes), throwsA(isA<TooManyPagesException>()));
    });
  });

  test('a password-protected PDF is reported as encrypted', () {
    final extractor = PdfrxTextExtractor(
      initialize: () async {},
      open: (_) => throw const PdfPasswordException('No password.'),
    );
    expect(
      extractor.extract(Uint8List.fromList(pdfHeader.codeUnits)),
      throwsA(isA<EncryptedPdfException>()),
    );
  });
}
