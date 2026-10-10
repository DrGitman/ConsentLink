# Usability, SUS, and fairness report

Replace bracketed prompts only with verified study records. Do not include
names, contact details, recordings, consent documents, or re-identification
keys. Store identifiable source records only in the team's approved restricted
storage.

## Study overview

- Study/prototype version: [describe]
- Round(s) and dates: [describe without identifying participants]
- Recruitment and participant profile: [report only approved, non-identifying aggregates]
- Tasks evaluated: [list task IDs and intended outcomes]
- Languages evaluated: [list language codes]
- Consent and data handling: [describe approved procedure and storage]

## Method

Describe the session procedure, task success criteria, comprehension checks,
SUS collection, missing-data handling, and any deviations from the
[usability test script](usability_test_script.md).

For SUS, report the number of complete and incomplete questionnaires for each
round. Score complete 10-item responses using the standard scoring method;
do not impute unanswered items. If reporting mean, median, minimum, or maximum,
state which complete responses are included.

For language-group task summaries, state the preselected minimum group-size
threshold, the denominator used for each outcome, and which outcomes or groups
were suppressed. The low-to-high rate ratio is descriptive only; it is not a
fairness threshold, significance test, or causal estimate.

## Results

### System Usability Scale

| Round | Complete responses | Incomplete responses | Mean | Median | Range |
|---|---:|---:|---:|---:|---:|
| [round] | [n] | [n] | [score] | [score] | [min–max] |

Interpretation tied to this sample and prototype: [describe cautiously]

### Task outcomes and comprehension

Report results separately by round and task. Follow the approved disclosure
threshold and do not expose suppressed counts through other tables or text.

| Round | Task | Language group/code | Attempted denominator | Success rate | Comprehension denominator | Comprehension rate |
|---|---|---|---:|---:|---:|---:|
| [round] | [task ID] | [group/code or suppressed] | [n or suppressed] | [rate or suppressed] | [n or suppressed] | [rate or suppressed] |

Descriptive differences and low-to-high ratios: [report eligible comparisons,
or state that results were not calculated because groups were suppressed or
outcomes were unavailable]

## Findings and design implications

- Observed usability barriers: [evidence-linked findings]
- Participant suggestions: [anonymized summary]
- Changes to prioritize and rationale: [list]
- Unresolved questions for another round: [list]

## Limitations and fairness considerations

Describe sample size and composition, groups not represented, missing or
unattempted tasks, prototype and facilitator effects, translation or
accessibility limitations, and other plausible confounders. These results are
exploratory and cannot establish that the system is fair or unfair. Do not
generalize beyond the participants, tasks, languages, and versions studied.

## Appendix: analysis checks

- Analysis tool/version: [record]
- Data validation performed: [record]
- Suppression threshold and approval basis: [record]
- Deviations or exclusions: [explain without identifying individuals]
