# ConsentLink

**Offline-first, multilingual digital informed consent for field research in Namibia.**

ConsentLink helps researchers turn a research proposal into a clear, approved consent form, then collect consent in the field. It works with no internet, in the participant's own language, and with read-aloud and voice answers. On-device AI drafts the form, and the researcher approves every section before anyone sees it.

> ConsentLink 2.0 is a full rebuild of the original ConsentLink prototype (Ndamonako & Indongo, 2026), developed as a group prototype project for **HCA820S – Human-Centred AI** at the Namibia University of Science and Technology (NUST).

---

## Features

**For researchers**
- Upload a proposal (PDF, DOCX, ODT, TXT, scans), or describe your study by voice or text, and get a draft consent form
- On-device AI drafting (no internet, proposal never leaves the phone), with source page, changes and confidence shown for every section
- A rule checker for the 10 required consent elements (plus 4 more for studies with minors)
- Section-by-section human approval: nothing reaches a participant unapproved
- Google-Forms-style form builder: text, choice, date, signature, thumbprint, audio, photo and GPS fields
- Analytics: recruitment progress, agreement rate, comprehension by language
- Export to PDF, Word (.docx) and CSV

**For participants**
- Large text, read-aloud on every screen, and voice or typed answers
- Equal-weight Yes / No choices (no nudging)
- Consent by signature, thumbprint or verbal recording, with a witness or interpreter
- Minors: guardian consent plus the child's own assent; the child's "No" always stops participation
- Optional feedback pop-up after completion (never shown to minors)

**For institutions**
- Each institution's template, logo and colours apply automatically to its researchers
- Admins upload a template; the app reads its fonts, spacing and margins and clips the logo from a PDF
- Dynamic theming per institution (UNAM, NUST, IUM, Welwitchia and more), with ConsentLink green as the default

**Languages:** English, Afrikaans, Deutsch, Otjiherero, Khoekhoegowab, Rukwangali, Silozi and Oshiwambo.
AI translations into local languages are always checked by a fluent human reviewer before use.

**Uploads:** executables, scripts and macro-enabled documents are blocked.

---

## Human-centred AI principles

ConsentLink is designed around the two-dimensional HCAI framework: **high automation and high human control**.

| Principle | In ConsentLink |
|---|---|
| Human oversight | AI drafts; researchers approve each section; fluent reviewers sign off translations |
| Transparency | Every AI section shows its source page, what changed and its confidence |
| Accountability | Append-only audit log of approvals, exports and withdrawals |
| Privacy & security | On-device AI, encrypted local storage, row-level security per institution |
| Fairness | Comprehension and completion compared across language groups |
| Autonomy | Participants control language, pace, text size and audio, and can say no without penalty |

Every screen must also pass our 11 design rules based on the UX laws (Hick, Fitts, Jakob, Miller, Peak-End, Aesthetic-Usability, hierarchy, consistency, accessibility, feedback, user control). See the Figma file.

---

## Tech stack

| Layer | Technology |
|---|---|
| App (Android, iOS, desktop) | Flutter, Riverpod, go_router |
| Local storage | drift (SQLite) + SQLCipher |
| Sync | PowerSync + Supabase |
| Backend | Supabase: Auth (email confirmation), Postgres + RLS, Storage, Edge Functions |
| On-device AI | llama.cpp with Gemma 4 E2B (fallback: Qwen 3.5 0.8B), GGUF format |
| Speech | whisper.cpp (EN/AF/DE), flutter_tts, recorded native-speaker audio |
| Document service | Python, FastAPI, PyMuPDF, python-docx, OpenCV, oletools, ClamAV |
| Export | pdf + printing, docx_template, CSV |
| CI/CD | GitHub Actions |

---

## Repository structure

```
ConsentLink/
├─ app/                Flutter app
│  ├─ lib/
│  │  ├─ core/         theme, router, feature flags, l10n      (P1)
│  │  ├─ contracts/    interfaces + models                     (ALL)
│  │  ├─ fakes/        fake implementations of each contract
│  │  ├─ features/     screens                                 (P1)
│  │  ├─ data/         database, repositories, sync, export    (P2)
│  │  ├─ ai/           model runtime, prompts, rules, speech   (P3)
│  │  ├─ main_dev.dart     runs on fakes
│  │  └─ main_demo.dart    runs on real implementations
│  ├─ l10n/            translations (.arb)
│  └─ test/
├─ service/            Python FastAPI document service         (P4)
├─ supabase/           migrations, seed data, RLS, functions   (P2)
├─ schemas/            shared JSON schemas                     (ALL)
├─ notebooks/          SUS + fairness analysis                 (P4)
├─ docs/               decisions, API notes, model card
└─ .github/            workflows, CODEOWNERS, PR template      (P2)
```

---

## Getting started

### Prerequisites
- Flutter (stable channel) and Android Studio or Xcode
- Python 3.12+
- Supabase CLI (optional; Docker is needed only for a local Supabase)
- A physical Android phone with 6 GB+ RAM for testing on-device AI

### 1. Clone and configure
```bash
git clone https://github.com/DrGitman/ConsentLink.git
cd ConsentLink
cp .env.example .env        # fill in values from the team (never commit .env)
```

### 2. Run the app on fakes (no backend needed)
```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -t lib/main_dev.dart
```

### 3. Run the app with real services
```bash
flutter run -t lib/main_demo.dart \
  --dart-define=USE_REAL_AI=true \
  --dart-define=USE_REAL_SYNC=true \
  --dart-define=USE_REAL_TEMPLATES=true
```
Any service can be switched back to its fake by setting its flag to `false`.

### 4. Run the Python service
```bash
cd service
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -e ".[dev]"
uvicorn app.main:app --reload      # http://localhost:8000/docs
```

### 5. Local Supabase (optional)
```bash
supabase start
supabase db reset                  # applies migrations + seed data
```

### AI model
Model files are **not** stored in Git. The app downloads the model after sign-in, on Wi-Fi (about 1.3 GB). For development, put the GGUF file path in `.env` (see `.env.example`).

---

## Working on this repo

We use **trunk-based development**: `main` is the only long-lived branch. Each member works on short-lived task branches under their own prefix:

| Member | Prefix | Example |
|---|---|---|
| P1 · UI & accessibility | `ui-dev/` | `ui-dev/7-onboarding-screens` |
| P2 · Data, sync & export | `data-dev/` | `data-dev/9-powersync-setup` |
| P3 · On-device AI & speech | `ai-dev/` | `ai-dev/12-rule-checker` |
| P4 · Python service & HCI | `py-dev/` | `py-dev/15-template-style-api` |

**Read [CONTRIBUTING.md](CONTRIBUTING.md) before your first branch.**

---

## Team

| Role | Member | GitHub |
|---|---|---|
| P1 · UI & accessibility | Orilio Naobeb| @DrGitman |
| P2 · Data, sync & export | Erastus Shingenge | @erastusshingenge-maker |
| P3 · On-device AI & speech | Amaury Cansa | @1Cansa |
| P4 · Python service & HCI |Kristofina Shipalanga | @Tuilika |

Lecturer: Mr Naftali N. Indongo, HCA820S, NUST.

---

## Design

All screens, the design system, diagrams, HCI roadmap and task plan are in the **ConsentLink Figma file**: _add link_.

| Figma page | What's there |
|---|---|
| App Identity | Logo, design system, the 11 design rules |
| Screen Artboards | All screens, numbered (e.g. `04.3`) |
| Development Diagrams | Architecture, contracts, work packages, sequences, integration plan |
| Design Diagrams | User flows and information architecture |
| HCI Roadmap | Course concepts applied, UX laws, personas, stakeholder session |
| Task Distribution and Planning | Roles, day-by-day plan, version control |
| Wireframes / Animations | Low-fi screens, motion specs |

Refer to screens by their number in issues and pull requests.

---

## Roadmap

| Date | Milestone |
|---|---|
| Sun 4 – Mon 5 Oct | Contracts + fakes merged, AI model spike |
| Tue 6 Oct | Stakeholder engagement session |
| Fri 9 Oct | Integration day |
| Sun 11 Oct | `v0.1.0` internal demo |
| Mon 12 Oct | Usability test round 1 |
| Fri 16 Oct | Usability test round 2 (SUS + fairness check) |
| Sun 18 Oct | `v1.0.0` release |

---

## Ethics and data

- Use **test data only** in development and shared environments. Never commit real participant data.
- Real data may only be collected under an approved ethics clearance.
- Studies with minors require ethics approval that covers minors, guardian consent and child assent.

---

## Acknowledgements

Builds on *ConsentLink: A Multilingual Digital Informed Consent Application for Research Data Collection in Namibia* (Ndamonako & Indongo, 2026, NUST).

## License

_To be decided by the team._
