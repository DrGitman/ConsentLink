import '../domain/consent_element.dart';
import '../domain/generated_consent_draft.dart';
import '../domain/generated_section.dart';
import '../domain/rule_report.dart';
import 'element_rules.dart';

/// The only language whose content the checks understand (decision D3.3).
const checkedLanguage = 'en';

const missingSectionHint = 'Add a section that covers this element.';
const notCheckedHint =
    'Not checked automatically in this language. Read it against the proposal.';

/// Checks [draft] against the required elements of [profile].
///
/// Deterministic: no section gives [RuleStatus.missing]; a section gives
/// [RuleStatus.ok] when its content checks pass, else [RuleStatus.uncertain].
RuleReport checkRules(GeneratedConsentDraft draft, StudyProfile profile) {
  final sections = {
    for (final section in draft.sections) section.element: section,
  };
  final contentChecked = _isCheckedLanguage(draft.formLanguage);
  return RuleReport(
    items: [
      for (final element in requiredElementsFor(profile))
        _checkElement(element, sections[element], contentChecked),
    ],
  );
}

RuleItem _checkElement(
  ConsentElement element,
  GeneratedSection? section,
  bool contentChecked,
) {
  if (section == null) {
    return RuleItem(
      element: element,
      status: RuleStatus.missing,
      fixHint: missingSectionHint,
    );
  }
  final checks = elementChecks[element] ?? const <ContentCheck>[];
  if (checks.isEmpty) return RuleItem(element: element, status: RuleStatus.ok);
  if (!contentChecked) return _uncertain(element, notCheckedHint);

  final text = '${section.title}\n${section.text}';
  final failedHints = [
    for (final check in checks)
      if (!check.pattern.hasMatch(text)) check.fixHint,
  ];
  return failedHints.isEmpty
      ? RuleItem(element: element, status: RuleStatus.ok)
      : _uncertain(element, failedHints.join(' '));
}

RuleItem _uncertain(ConsentElement element, String hint) =>
    RuleItem(element: element, status: RuleStatus.uncertain, fixHint: hint);

// Accepts regional tags such as `en-NA`.
bool _isCheckedLanguage(String languageCode) =>
    languageCode.split('-').first.toLowerCase() == checkedLanguage;
