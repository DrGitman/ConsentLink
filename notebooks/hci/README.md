# HCI analysis templates

These tools prepare analysis for the planned SUS and usability/fairness
evaluation. They contain no participant responses. Do not put names, contact
details, recordings, consent documents, or re-identification keys in this
folder.

## Input data

Keep session-level source data outside Git in the team's approved restricted
storage. Use random session codes that are not linked to identities.

### SUS response CSV

One row per session; columns:

```text
session_code,round,item_1,item_2,item_3,item_4,item_5,item_6,item_7,item_8,item_9,item_10
```

Item values must be integers 1–5. Leave an unanswered item blank; the score
will be reported as incomplete, without imputation.

### Usability outcome CSV

One row per session per task; columns:

```text
session_code,round,language_code,task_id,task_attempted,task_success,comprehension_correct
```

Boolean values must be `true` or `false`; `comprehension_correct` may be blank
when it was not assessed. Only include anonymous language codes and test
outcomes. Do not treat missing or unattempted tasks as failures.

## Analysis

`analysis.py` implements:

- CSV loaders for the schemas above (`load_sus_csv` and `load_outcome_csv`).
- Standard 10-item SUS scoring (odd items: response − 1; even items: 5 −
  response; sum × 2.5). Incomplete responses are not scored.
- Per-round SUS summaries and per-task success/comprehension rates by language.
- A low-to-high observed outcome-rate ratio as a descriptive diagnostic only.
- Suppression of language groups below a caller-selected minimum group size.

The minimum group size is required explicitly; select it with the team and
ethics/privacy guidance before analysis. Suppression of small groups is not a
complete privacy guarantee. Review all exports for re-identification risk.
Small, uneven, or absent groups, prototypes, and confounding mean these results
cannot establish fairness or statistical significance. Report denominators and
limitations, and compare iteration outcomes cautiously.

Import the helpers from this directory in a Python session or another local
analysis script. Use `summarize_sus_by_round(load_sus_csv(path))` for
round-separated SUS results and
`summarize_language_outcomes(load_outcome_csv(path), min_group_size=N)` for
round-separated task outcomes. The round label is required and the same
session/task can appear once in each round. Choose the suppression threshold
with the team and ethics/privacy guidance; do not commit source CSV files or
results that could identify participants.

Use [report_template.md](report_template.md) to write up observed results,
methods, and limitations without presenting descriptive group comparisons as
proof of fairness.

To run the unit tests using the service virtual environment:

```powershell
Set-Location -LiteralPath "C:\Users\shtuw\Documents\HCA\ConsentLink\notebooks\hci"
..\..\service\.venv\Scripts\python.exe -m pytest -q
```

See [usability_test_script.md](usability_test_script.md) and
[sus_worksheet.md](sus_worksheet.md) for collection procedures.
