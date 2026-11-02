import 'dart:developer' show log;
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../ai_exceptions.dart';
import 'proposal_file_guard.dart';
import 'proposal_page.dart';
import 'proposal_text_extractor.dart';

/// Opens PDF bytes. Replaced in tests to simulate pdfrx errors.
typedef PdfOpener = Future<PdfDocument> Function(Uint8List bytes);

const _logName = 'ai.pdf';

Future<PdfDocument> _openData(Uint8List bytes) => PdfDocument.openData(bytes);

Future<void> _flutterInitialize() async => pdfrxFlutterInitialize();

/// [ProposalTextExtractor] on PDFium (pdfrx), bundled in the app.
///
/// Only opens bytes in memory: no file path, no URL, no network.
final class PdfrxTextExtractor implements ProposalTextExtractor {
  const PdfrxTextExtractor({
    this.initialize = _flutterInitialize,
    this.open = _openData,
  });

  /// Loads PDFium once. Host tests pass `pdfrxInitialize` instead.
  final Future<void> Function() initialize;
  final PdfOpener open;

  @override
  Future<List<ProposalPage>> extract(Uint8List bytes) async {
    checkProposalBytes(bytes);
    final stopwatch = Stopwatch()..start();
    await initialize();
    final document = await _openDocument(bytes);
    try {
      // Before reading any text, so a huge PDF costs nothing.
      checkProposalPageCount(document.pages.length);
      final pages = [
        for (final page in document.pages)
          ProposalPage(
            pageNumber: page.pageNumber,
            text: await page.loadText(),
          ),
      ];
      log(
        'Read ${pages.length} pages in ${stopwatch.elapsedMilliseconds} ms',
        name: _logName,
      );
      return requireTextLayer(pages);
    } finally {
      await document.dispose();
    }
  }

  Future<PdfDocument> _openDocument(Uint8List bytes) async {
    try {
      return await open(bytes);
    } on PdfPasswordException {
      throw const EncryptedPdfException(
        'The PDF is password-protected. Upload a copy without a password.',
      );
    } on PdfException {
      throw const CorruptedPdfException('The file is not a readable PDF.');
    }
  }
}
