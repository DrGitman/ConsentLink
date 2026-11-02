import 'dart:typed_data';

import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/pdf/proposal_file_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// [length] bytes with the PDF header written at [headerAt].
Uint8List _file(int length, {int headerAt = 0}) =>
    Uint8List(length)..setAll(headerAt, pdfHeader.codeUnits);

void main() {
  group('checkProposalBytes', () {
    test('accepts a PDF of exactly $maxProposalBytes bytes', () {
      expect(
        () => checkProposalBytes(_file(maxProposalBytes)),
        returnsNormally,
      );
    });

    test('refuses one byte more', () {
      expect(
        () => checkProposalBytes(_file(maxProposalBytes + 1)),
        throwsA(isA<ProposalTooLargeException>()),
      );
    });

    test('refuses an empty file', () {
      expect(
        () => checkProposalBytes(Uint8List(0)),
        throwsA(isA<CorruptedPdfException>()),
      );
    });

    test('refuses a file without a PDF header', () {
      final text = Uint8List.fromList('Not a PDF at all'.codeUnits);
      expect(
        () => checkProposalBytes(text),
        throwsA(isA<CorruptedPdfException>()),
      );
    });

    test('accepts a header after a few junk bytes', () {
      expect(
        () => checkProposalBytes(_file(100, headerAt: 3)),
        returnsNormally,
      );
    });

    test('refuses a header past the first $pdfHeaderSearchBytes bytes', () {
      expect(
        () => checkProposalBytes(_file(2048, headerAt: pdfHeaderSearchBytes)),
        throwsA(isA<CorruptedPdfException>()),
      );
    });
  });

  group('checkProposalPageCount', () {
    test('accepts $maxProposalPages pages', () {
      expect(() => checkProposalPageCount(maxProposalPages), returnsNormally);
    });

    test('refuses one page more, and says how many', () {
      expect(
        () => checkProposalPageCount(maxProposalPages + 1),
        throwsA(
          isA<TooManyPagesException>().having(
            (error) => error.message,
            'message',
            contains('${maxProposalPages + 1} pages'),
          ),
        ),
      );
    });
  });
}
