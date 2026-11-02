import '../domain/consent_element.dart';
import '../pdf/proposal_page.dart';
import 'element_guidance.dart';

/// Page text sent per model call: ~2,500 tokens at ~4 characters per token,
/// leaving room in the 4,096-token context for the prompt and the answer.
const maxPromptPageChars = 10000;

/// Picks the proposal pages most about [element], within [maxChars].
///
/// Pages are ranked by keyword hits and returned in reading order. Without
/// any hit, the first pages are used so the model can still decide (D5.7).
/// A first page longer than [maxChars] is cut.
List<ProposalPage> selectPagesFor(
  ConsentElement element,
  List<ProposalPage> pages, {
  int maxChars = maxPromptPageChars,
}) {
  if (pages.isEmpty) {
    throw ArgumentError.value(pages, 'pages', 'Is empty');
  }
  if (maxChars < 1) {
    throw RangeError.value(maxChars, 'maxChars', 'Must be >= 1');
  }
  final ranked = _rankedByHits(element, pages);
  final selected = _fill(ranked.isEmpty ? pages : ranked, maxChars)
    ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
  return List.unmodifiable(selected);
}

List<ProposalPage> _rankedByHits(
  ConsentElement element,
  List<ProposalPage> pages,
) {
  final pattern = _keywordPattern(element);
  final hits = {
    for (final page in pages) page: pattern.allMatches(page.text).length,
  };
  // List.sort is not stable: ties go to the earlier page.
  return pages.where((page) => hits[page]! > 0).toList()..sort(
    (a, b) => hits[a] == hits[b]
        ? a.pageNumber.compareTo(b.pageNumber)
        : hits[b]!.compareTo(hits[a]!),
  );
}

RegExp _keywordPattern(ConsentElement element) {
  final keywords = elementGuidance[element]!.proposalKeywords.map(
    RegExp.escape,
  );
  return RegExp(
    '\\b(${keywords.join('|')})',
    caseSensitive: false,
    unicode: true,
  );
}

List<ProposalPage> _fill(List<ProposalPage> candidates, int maxChars) {
  final selected = <ProposalPage>[];
  var remaining = maxChars;
  for (final page in candidates) {
    if (page.text.length <= remaining) {
      selected.add(page);
      remaining -= page.text.length;
    } else if (selected.isEmpty) {
      selected.add(
        ProposalPage(
          pageNumber: page.pageNumber,
          text: page.text.substring(0, remaining),
        ),
      );
      break;
    }
  }
  return selected;
}
