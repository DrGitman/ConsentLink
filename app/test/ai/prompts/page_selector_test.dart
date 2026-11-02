import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/pdf/proposal_page.dart';
import 'package:consentlink/ai/prompts/element_guidance.dart';
import 'package:consentlink/ai/prompts/page_selector.dart';
import 'package:flutter_test/flutter_test.dart';

ProposalPage _page(int number, String text) =>
    ProposalPage(pageNumber: number, text: text);

List<int> _numbers(List<ProposalPage> pages) =>
    pages.map((page) => page.pageNumber).toList();

void main() {
  test('every element has keywords and an instruction', () {
    for (final element in ConsentElement.values) {
      final guidance = elementGuidance[element];
      expect(guidance, isNotNull, reason: element.jsonKey);
      expect(guidance!.proposalKeywords, isNotEmpty);
      for (final keyword in guidance.proposalKeywords) {
        expect(keyword, keyword.toLowerCase());
      }
      expect(guidance.instruction.trim(), isNotEmpty);
    }
  });

  group('selectPagesFor', () {
    final pages = [
      _page(1, 'Title page of an invented study.'),
      _page(2, 'There is a small risk of distress.'),
      _page(3, 'Risks: tiredness. Harm is unlikely. Risk of discomfort.'),
      _page(4, 'Budget and timeline.'),
    ];

    test('keeps pages with hits, most hits first, in reading order', () {
      final selected = selectPagesFor(ConsentElement.risks, pages);
      expect(_numbers(selected), [2, 3]);
    });

    test('matches keywords case-insensitively, as word starts', () {
      final selected = selectPagesFor(ConsentElement.risks, [
        _page(1, 'RISKS are low.'),
        _page(2, 'Asterisk only.'),
      ]);
      expect(_numbers(selected), [1]);
    });

    test('drops lower-ranked pages that do not fit the budget', () {
      final selected = selectPagesFor(
        ConsentElement.risks,
        pages,
        maxChars: pages[2].text.length + 5,
      );
      expect(_numbers(selected), [3]);
    });

    test('uses the first pages when no page has a hit (D5.7)', () {
      final selected = selectPagesFor(
        ConsentElement.compensation,
        pages,
        maxChars: pages[0].text.length + pages[1].text.length,
      );
      expect(_numbers(selected), [1, 2]);
    });

    test('cuts a first page longer than the budget', () {
      final selected = selectPagesFor(ConsentElement.risks, [
        _page(7, 'Risk ${'x' * 50}'),
      ], maxChars: 10);
      expect(selected.single.pageNumber, 7);
      expect(selected.single.text, 'Risk xxxxx');
    });

    test('rejects no pages and a budget below 1', () {
      expect(
        () => selectPagesFor(ConsentElement.risks, const []),
        throwsArgumentError,
      );
      expect(
        () => selectPagesFor(ConsentElement.risks, pages, maxChars: 0),
        throwsRangeError,
      );
    });
  });
}
