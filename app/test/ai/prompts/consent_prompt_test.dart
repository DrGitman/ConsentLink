import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/pdf/proposal_page.dart';
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
