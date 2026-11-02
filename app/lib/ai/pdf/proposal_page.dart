import '../domain/generated_section.dart' show firstPageNumber;

/// The text of one page of the uploaded proposal.
final class ProposalPage {
  /// Throws a [RangeError] when [pageNumber] is below [firstPageNumber].
  ProposalPage({required this.pageNumber, required this.text}) {
    if (pageNumber < firstPageNumber) {
      throw RangeError.value(pageNumber, 'pageNumber', 'Pages start at 1');
    }
  }

  final int pageNumber;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is ProposalPage &&
      other.pageNumber == pageNumber &&
      other.text == text;

  @override
  int get hashCode => Object.hash(pageNumber, text);
}
