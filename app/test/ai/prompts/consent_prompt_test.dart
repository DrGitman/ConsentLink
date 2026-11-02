import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/pdf/proposal_page.dart';
import 'package:consentlink/ai/prompts/consent_output_parser.dart';
import 'package:consentlink/ai/prompts/consent_prompt.dart';
import 'package:consentlink/ai/prompts/element_guidance.dart';
import 'package:consentlink/ai/prompts/section_grammar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/khoekhoegowab_fixture.dart';

void main() {
  final pages = [
    ProposalPage(pageNumber: 2, text: 'Participants answer a survey.'),
    ProposalPage(pageNumber: 5, text: 'Each visit lasts 30 minutes.'),
  ];

  test('builds a constrained request for one element', () {
    final prompt = buildSectionPrompt(ConsentElement.duration, pages);

    expect(prompt.system, consentSystemPrompt);
    expect(prompt.maxTokens, sectionMaxTokens);
    expect(
      prompt.grammar,
      sectionGrammar(ConsentElement.duration, draftLanguage),
    );
    expect(prompt.user, contains('Element key: duration'));
    expect(
      prompt.user,
      contains(elementGuidance[ConsentElement.duration]!.instruction),
    );
  });

  test('marks each page with its number, in the given order', () {
    final user = buildSectionPrompt(ConsentElement.procedures, pages).user;

    expect(user, contains('[Page 2]\nParticipants answer a survey.'));
    expect(user, contains('[Page 5]\nEach visit lasts 30 minutes.'));
    expect(user.indexOf('[Page 2]'), lessThan(user.indexOf('[Page 5]')));
  });

  test('spells out both answers, citing a given page', () {
    final user = buildSectionPrompt(ConsentElement.duration, pages).user;

    expect(user, contains('"sections":[{"key":"duration",'));
    expect(user, contains('"source_pages":[2]'));
    expect(user, endsWith(missingAnswerFor(ConsentElement.duration)));
  });

  test('the "missing" answer is read as a clean missing element', () {
    final parsed = parseConsentDraft(missingAnswerFor(ConsentElement.risks));

    expect(parsed.issues, isEmpty);
    expect(parsed.draft.sections, isEmpty);
    expect(parsed.draft.missing, [ConsentElement.risks]);
  });

  test('keeps click letters unchanged (task K)', () {
    final user = buildSectionPrompt(ConsentElement.purpose, [
      ProposalPage(pageNumber: 1, text: khoekhoegowabSentence),
    ]).user;

    expect(user, contains(khoekhoegowabSentence));
    for (final click in allClickLetters) {
      expect(user, contains(click));
    }
  });

  test('rejects an empty page list', () {
    expect(
      () => buildSectionPrompt(ConsentElement.purpose, const []),
      throwsArgumentError,
    );
  });
}
