import 'dart:typed_data';

import '../ai_exceptions.dart';
import 'proposal_page.dart';

/// Reads the text of a proposal file page by page, on the device only.
abstract interface class ProposalTextExtractor {
  /// Throws an [EncryptedPdfException], a [ScannedPdfException], a
  /// [CorruptedPdfException], a [ProposalTooLargeException] or a
  /// [TooManyPagesException].
  Future<List<ProposalPage>> extract(Uint8List bytes);
}

/// A page with fewer visible characters holds no real text (decision D2.2).
const minCharsForTextPage = 20;

final _whitespace = RegExp(r'\s', unicode: true);

/// Returns [pages] when at least one page has real text.
///
/// Throws a [ScannedPdfException] otherwise. Pages with little text, such as
/// a cover or a figure, are kept as they are.
List<ProposalPage> requireTextLayer(List<ProposalPage> pages) {
  final hasText = pages.any(
    (page) =>
        page.text.replaceAll(_whitespace, '').runes.length >=
        minCharsForTextPage,
  );
  if (!hasText) {
    throw const ScannedPdfException(
      'The PDF has no text. It may be scanned; upload a PDF with text.',
    );
  }
  return pages;
}
