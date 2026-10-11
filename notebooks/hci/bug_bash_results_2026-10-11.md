# P4 bug-bash results — 11 October 2026

## Scope and test data

Checks were run on `py-dev/29-bug-bash` against the local P4 service and HCI
materials. Service endpoint tests use generated synthetic files and mocked
Supabase Storage responses. No participant data, live storage credentials, or
production files were used.

## Python service

Command:

```powershell
Set-Location -LiteralPath "C:\Users\shtuw\Documents\HCA\ConsentLink\service"
.\.venv\Scripts\python.exe -m pytest -q
```

Result: **37 passed**. The suite emitted third-party deprecation warnings from
Starlette/httpx and oletools/pyparsing; there were no test failures.

Health checks using FastAPI's local test client:

| Endpoint | Result |
|---|---|
| `GET /health` | 200, `{"status":"ok"}` |
| `GET /v1/health` | 200, `{"ok":true,"version":"0.1.0"}` |

Coverage in the passing test suite includes:

- File-safety scans of synthetic supported, unsafe, mismatched, and oversized
  files, including authentication and error cases.
- Template style extraction from generated PDF and DOCX fixtures.
- Logo extraction from a generated PDF, including PNG output and invalid crop
  handling.
- Template-analysis and logo-extraction endpoint flows using mocked Storage
  downloads/uploads and caller JWTs.

No reproducible service defect was found in these checks. Live Supabase
Storage, deployed-service networking, and production credentials were not
tested; those require a separately approved environment and are not implied by
the mocked endpoint results.

## HCI materials review

Reviewed [usability_test_script.md](usability_test_script.md) and
[sus_worksheet.md](sus_worksheet.md).

- The usability script specifies consent, synthetic sample information,
  anonymous session codes, neutral prompts, task success criteria, not-testable
  handling, and round-level summaries.
- It cautions against treating prototypes as working features and against
  overclaiming from a small sample.
- The SUS worksheet directs the team to use the authorized 10-item wording
  unchanged and does not reproduce the questionnaire. It provides standard
  scoring, incomplete-response handling, and cautious interpretation.
- No content defect was identified that blocks the planned sessions.

## Before usability sessions

- Confirm the applicable ethics/course approval and approved session procedure.
- Prepare only synthetic sample content and record the exact test build/version.
- Mark absent or simulated features as **Not testable**; do not present them as
  implemented.
- Keep session-level worksheets and any consent records in approved restricted
  storage. Do not add individual responses, raw notes, recordings, or
  re-identification material to Git or public reports.
- Record build limitations and actual sample counts when writing up results.
