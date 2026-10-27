import 'package:consentlink/contracts/models.dart' show Confidence;

import '../domain/consent_element.dart';
import '../domain/generated_consent_draft.dart';
import '../domain/generated_section.dart';
import '../domain/rule_report.dart';

// Invented data for an imaginary water study; not a real proposal.
const fakeFormLanguage = 'en';
const fakeReadingGrade = 6.0;
const fakeMissingHint = 'Add a section that covers this element.';

GeneratedSection _section(
  ConsentElement element,
  String title,
  String text,
  int page, {
  String? quote,
  List<String> changes = const [],
  Confidence confidence = Confidence.high,
}) => GeneratedSection(
  element: element,
  title: title,
  text: text,
  sourcePages: [page],
  sourceQuote: quote,
  changes: changes,
  confidence: confidence,
);

/// Nine of the ten core elements: `contacts_ethics` is left out on purpose.
final fakeSampleSections = List<GeneratedSection>.unmodifiable([
  _section(
    ConsentElement.purpose,
    'Purpose of the study',
    'We want to learn how families get clean water.',
    2,
    quote: 'This study investigates household water access.',
    changes: ['Reading level: university to Grade 6'],
  ),
  _section(
    ConsentElement.procedures,
    'What you will do',
    'You will answer questions in one interview.',
    5,
  ),
  _section(
    ConsentElement.duration,
    'How long it takes',
    'The interview takes about 40 minutes.',
    5,
  ),
  _section(
    ConsentElement.risks,
    'Risks',
    'You may feel tired. You can rest or stop at any time.',
    6,
    confidence: Confidence.medium,
  ),
  _section(
    ConsentElement.benefits,
    'Possible benefits',
    'There is no direct benefit to you.',
    6,
  ),
  _section(
    ConsentElement.compensation,
    'Payment',
    'You will not be paid. We will give you water and a snack.',
    7,
  ),
  _section(
    ConsentElement.confidentiality,
    'Your privacy',
    'Your name will not be on your answers. '
        'We keep your answers safely for 5 years, then delete them.',
    8,
    changes: ['Added how long the answers are kept'],
  ),
  _section(
    ConsentElement.voluntaryWithdrawal,
    'Your choice',
    'Taking part is your choice. You can say no or stop at any time. '
        'Nothing bad will happen to you.',
    8,
  ),
  _section(
    ConsentElement.contactsResearcher,
    'Questions',
    'You can ask the researcher questions now or later.',
    9,
    confidence: Confidence.low,
  ),
]);

/// The sample draft; required elements without a section are [missing].
GeneratedConsentDraft fakeSampleDraftFor(StudyProfile profile) {
  final drafted = fakeSampleSections.map((section) => section.element);
  return GeneratedConsentDraft(
    formLanguage: fakeFormLanguage,
    readingGrade: fakeReadingGrade,
    sections: fakeSampleSections,
    missing: [
      for (final element in requiredElementsFor(profile))
        if (!drafted.contains(element)) element,
    ],
  );
}

/// One item per required element: ok when [draft] has a section for it.
RuleReport fakeRuleReportFor(
  GeneratedConsentDraft draft,
  StudyProfile profile,
) {
  final drafted = draft.sections.map((section) => section.element).toSet();
  return RuleReport(
    items: [
      for (final element in requiredElementsFor(profile))
        drafted.contains(element)
            ? RuleItem(element: element, status: RuleStatus.ok)
            : RuleItem(
                element: element,
                status: RuleStatus.missing,
                fixHint: fakeMissingHint,
              ),
    ],
  );
}
