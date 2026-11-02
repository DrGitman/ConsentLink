import 'dart:typed_data';

import '../ai_exceptions.dart';

/// Same limits as the server's template scan (`service/app/`), decision D2b.1.
const maxProposalBytes = 25 * 1024 * 1024;
const maxProposalPages = 60;

const _bytesPerMegabyte = 1024 * 1024;

/// Every PDF starts with this header. Readers accept it anywhere in the
/// first [pdfHeaderSearchBytes] bytes, after junk some tools write.
const pdfHeader = '%PDF-';
const pdfHeaderSearchBytes = 1024;

/// Checks the file before PDFium opens it.
///
/// Throws a [CorruptedPdfException] for an empty file or one without a PDF
/// header, and a [ProposalTooLargeException] above [maxProposalBytes].
void checkProposalBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const CorruptedPdfException('The file is empty.');
  }
  if (bytes.length > maxProposalBytes) {
    throw ProposalTooLargeException(
      'The file is larger than ${maxProposalBytes ~/ _bytesPerMegabyte} MB. '
      'Upload a smaller PDF.',
    );
  }
  if (!_hasPdfHeader(bytes)) {
    throw const CorruptedPdfException('The file is not a PDF.');
  }
}

/// Throws a [TooManyPagesException] above [maxProposalPages].
void checkProposalPageCount(int pageCount) {
  if (pageCount > maxProposalPages) {
    throw TooManyPagesException(
      'The PDF has $pageCount pages; the limit is $maxProposalPages. '
      'Upload only the parts participants need.',
    );
  }
}

bool _hasPdfHeader(Uint8List bytes) {
  final end = bytes.length < pdfHeaderSearchBytes
      ? bytes.length
      : pdfHeaderSearchBytes;
  final start = String.fromCharCodes(Uint8List.sublistView(bytes, 0, end));
  return start.contains(pdfHeader);
}
