import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/domain/generated_consent_draft.dart';
import 'package:consentlink/ai/domain/generated_section.dart';
import 'package:consentlink/ai/domain/rule_report.dart';
import 'package:consentlink/ai/drafting/fake_sample_draft.dart';
import 'package:consentlink/ai/rules/rule_checker.dart';
import 'package:consentlink/contracts/models.dart' show Confidence;
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/khoekhoegowab_fixture.dart';

GeneratedSection _section(ConsentElement element, String text) =>
    GeneratedSection(
      element: element,
      title: 'Section',
      text: text,
      sourcePages: const [1],
      changes: const [],
      confidence: Confidence.high,
    );

GeneratedConsentDraft _draft(
  List<GeneratedSection> sections, {
  String language = 'en',
}) => GeneratedConsentDraft(
  formLanguage: language,
  readingGrade: null,
  sections: sections,
  missing: const [],
);

RuleItem _itemFor(
  ConsentElement element,
  String text, {
  String language = 'en',
  StudyProfile profile = StudyProfile.minors,
}) => checkRules(
  _draft([_section(element, text)], language: language),
  profile,
).items.singleWhere((item) => item.element == element);

Matcher _isStatus(RuleStatus status) =>
    isA<RuleItem>().having((item) => item.status, 'status', status);

void main() {
  group('profiles', () {
    test('a standard study checks the 10 core elements', () {
      final report = checkRules(_draft(const []), StudyProfile.standard);
      expect(report.required, 10);
    });

    test('a study with minors checks 14 elements', () {
      final report = checkRules(_draft(const []), StudyProfile.minors);
      expect(report.required, 14);
    });
  });

  test('an element without a section is missing, with a hint', () {
    final report = checkRules(_draft(const []), StudyProfile.standard);
    expect(report.found, 0);
    expect(
      report.items.first,
      isA<RuleItem>()
          .having((item) => item.status, 'status', RuleStatus.missing)
          .having((item) => item.fixHint, 'fixHint', missingSectionHint),
    );
  });

  test('an element without content checks is ok once present', () {
    expect(
      _itemFor(ConsentElement.risks, 'You may feel tired.'),
      _isStatus(RuleStatus.ok),
    );
  });

  group('content checks (English)', () {
    test('confidentiality must say how long answers are kept', () {
      expect(
        _itemFor(ConsentElement.confidentiality, 'Your name stays private.'),
        _isStatus(RuleStatus.uncertain),
      );
      expect(
        _itemFor(ConsentElement.confidentiality, 'We keep them for 5 years.'),
        _isStatus(RuleStatus.ok),
      );
    });

    test('withdrawal must say stopping has no penalty', () {
      final item = _itemFor(
        ConsentElement.voluntaryWithdrawal,
        'You can stop at any time.',
      );
      expect(item.status, RuleStatus.uncertain);
      expect(item.fixHint, contains('no penalty'));
      expect(
        _itemFor(
          ConsentElement.voluntaryWithdrawal,
          'You can stop at any time. It won’t affect your care.',
        ),
        _isStatus(RuleStatus.ok),
      );
    });

    test('every failed check adds its hint', () {
      final item = _itemFor(ConsentElement.contactsEthics, 'Ask us anything.');
      expect(item.fixHint, contains('ethics committee.'));
      expect(item.fixHint, contains('phone or email'));
    });

    test('contacts need a phone number or an email', () {
      expect(
        _itemFor(ConsentElement.contactsResearcher, 'Call +264 61 207 9111.'),
        _isStatus(RuleStatus.ok),
      );
      expect(
        _itemFor(ConsentElement.contactsResearcher, 'Ask the researcher.'),
        _isStatus(RuleStatus.uncertain),
      );
    });

    test("the child's no must be respected", () {
      expect(
        _itemFor(
          ConsentElement.childDissentRespected,
          'You can say no. That is always okay.',
        ),
        _isStatus(RuleStatus.ok),
      );
      expect(
        _itemFor(ConsentElement.childDissentRespected, 'Please join us.'),
        _isStatus(RuleStatus.uncertain),
      );
    });

    test('a regional English tag is still checked', () {
      expect(
        _itemFor(
          ConsentElement.duration,
          'About 40 minutes.',
          language: 'en-NA',
        ),
        _isStatus(RuleStatus.ok),
      );
    });
  });

  test('the fake sample draft gets the expected verdicts', () {
    final report = checkRules(
      fakeSampleDraftFor(StudyProfile.standard),
      StudyProfile.standard,
    );
    final statuses = {
      for (final item in report.items) item.element: item.status,
    };
    expect(statuses[ConsentElement.confidentiality], RuleStatus.ok);
    expect(statuses[ConsentElement.voluntaryWithdrawal], RuleStatus.ok);
    expect(statuses[ConsentElement.contactsResearcher], RuleStatus.uncertain);
    expect(statuses[ConsentElement.contactsEthics], RuleStatus.missing);
    expect(report.found, 8);
  });

  group('Khoekhoegowab clicks (task K)', () {
    test('other languages are not checked, never wrongly ok', () {
      final item = _itemFor(
        ConsentElement.confidentiality,
        khoekhoegowabSentence,
        language: khoekhoegowabCode,
      );
      expect(item.status, RuleStatus.uncertain);
      expect(item.fixHint, notCheckedHint);
    });

    test('a section in Khoekhoegowab without checks is ok', () {
      expect(
        _itemFor(
          ConsentElement.purpose,
          khoekhoegowabSentence,
          language: khoekhoegowabCode,
        ),
        _isStatus(RuleStatus.ok),
      );
    });

    test('a click letter in English text does not break the checks', () {
      expect(
        _itemFor(
          ConsentElement.contactsResearcher,
          'Call $clickResearcherName on 061 207 9111.',
        ),
        _isStatus(RuleStatus.ok),
      );
    });

    test('the click letters are distinct code points', () {
      expect(allClickLetters.map((letter) => letter.runes.single).toList(), [
        0x01C0,
        0x01C1,
        0x01C2,
        0x01C3,
      ]);
    });
  });
}
