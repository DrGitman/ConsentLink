# Contributing to ConsentLink

This guide explains how the four of us work in parallel without blocking each other. The full diagrams are in the Figma file:
- **Development Diagrams**: sections E–L
- **Task Distribution and Planning**: sections D–F

---

## 1. How we branch: trunk-based development

- `main` is the **only** long-lived branch. It always holds the full, working source code.
- There is no `dev` or `prod` branch. APKs are built from `main` by CI. They are never committed.
- Each member has a **prefix**. You create a **new branch for every task** under your prefix.
- A branch lives **1–2 days at most**. It is then merged into `main` through a pull request and deleted.

| Member | Prefix | Owns |
|---|---|---|
| P1 · UI & accessibility | `ui-dev/` | `app/lib/core`, `app/lib/features`, `app/l10n` |
| P2 · Data, sync & export | `data-dev/` | `app/lib/data`, `supabase/`, `.github/` |
| P3 · On-device AI & speech | `ai-dev/` | `app/lib/ai` |
| P4 · Python service & HCI | `py-dev/` | `service/`, `notebooks/` |
| Shared (needs every consumer's approval) | — | `app/lib/contracts`, `schemas/` |

### Branch names
```
<prefix>/<issue-number>-<short-description>
```
- `ui-dev/7-onboarding-screens`
- `data-dev/9-powersync-setup`
- `ai-dev/12-rule-checker`
- `py-dev/15-template-style-api`

Branch names are **always lowercase**, with words separated by hyphens. Mixed case causes checkout errors on Windows and macOS.

---

## 2. The daily loop (per task)

```bash
# 1. Start from the latest main
git switch main
git pull

# 2. Create your task branch
git switch -c ai-dev/12-rule-checker

# 3. Work in small commits
git add .
git commit -m "feat(ai): add rule checker for required elements"

# 4. Sync with main at least once a day
git pull --rebase origin main

# 5. Push and open a pull request
git push -u origin HEAD

# 6. After it is merged, clean up and start the next task
git switch main
git pull
git branch -d ai-dev/12-rule-checker
```

If a task will take longer than 2 days, split it into smaller issues. You can also merge unfinished work behind a feature flag (see section 5).

---

## 3. Rules that keep us out of each other's way

1. **Only edit files in your own folders.** If you need a change elsewhere, open an issue for the owner or pair for 15 minutes.
2. **Never import another feature's internals.** Only import from `app/lib/contracts/`. CI checks this.
3. **Contracts change first, implementations after.** A change to `contracts/` or `schemas/` is its own pull request and must be approved by every consumer. Never mix a contract change and its implementation in one PR.
4. **Every contract ships with a fake** in `app/lib/fakes/`, in the same pull request, so consumers can start immediately.
5. **Refer to Figma screens by number** (e.g. `04.3`) in issues, commits and pull requests.

---

## 4. Commits

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<area>): <what changed>
```

| Type | Use for |
|---|---|
| `feat` | a new feature |
| `fix` | a bug fix |
| `docs` | documentation only |
| `test` | adding or fixing tests |
| `refactor` | code change with no behaviour change |
| `chore` | tooling, CI, dependencies |

Areas: `ui`, `data`, `ai`, `py`, `contracts`, `schemas`, `ci`.

Examples:
```
feat(ui): add consent choices screen (06.4)
fix(data): stop duplicate rows after offline sync
feat(contracts): add SpeechService.canTranscribe
```

---

## 5. Working without waiting for each other

**Fakes.** Every interface in `contracts/` has a fake that returns canned data.
- `main_dev.dart` runs the whole app on fakes.
- `main_demo.dart` runs on real implementations.

**Feature flags.** Unfinished features can be merged "dark":
```dart
class FeatureFlags {
  static const useRealAi = bool.fromEnvironment('USE_REAL_AI');
  static const useRealSync = bool.fromEnvironment('USE_REAL_SYNC');
  static const useRealTemplates = bool.fromEnvironment('USE_REAL_TEMPLATES');
  static const wordExport = bool.fromEnvironment('WORD_EXPORT');
}
```
```bash
flutter run -t lib/main_demo.dart --dart-define=USE_REAL_AI=true
```

**Contract tests.** The same test suite runs against the fake **and** the real implementation. If both pass, swapping one for the other is safe.

The dated order for swapping each fake for the real version is in **Development Diagrams → K**.

---

## 6. Pull requests

- One task per pull request. Aim for under 400 changed lines.
- Link the issue (`Closes #12`) and the Figma screen number.
- 1 approval is required. CODEOWNERS requests the right reviewer automatically.
- Review within 12 hours.
- **Squash-merge**, then delete the branch.

### PR checklist (also in `.github/pull_request_template.md`)

**General**
- [ ] Matches its Figma frame (number: ___)
- [ ] Works in airplane mode, or explains why it can't
- [ ] Every control has a screen-reader label
- [ ] No hard-coded text (strings are in `l10n/`)
- [ ] Tests added or updated; CI is green

**The 11 design rules (UX laws)**
- [ ] Hick: at most 1 primary + 2 secondary actions
- [ ] Fitts: targets ≥ 48 dp, primary action at the bottom
- [ ] Jakob: platform patterns used
- [ ] Miller: ≤ 7 items per group
- [ ] Peak-End: flow ends on a success screen
- [ ] Aesthetic: 8 dp grid, library components only
- [ ] Hierarchy: one headline, key item largest
- [ ] Consistency: same word, icon and position for the same action
- [ ] Accessibility: contrast ≥ 4.5:1, works at 200% text, labels present
- [ ] Feedback: response < 100 ms, progress shown for waits
- [ ] User control: back / undo / confirm destructive actions

---

## 7. Labels

| Group | Labels |
|---|---|
| Owner | `P1-UI`, `P2-Data`, `P3-AI`, `P4-Python` |
| Type | `Contract`, `Fake`, `Bug`, `UX-Law`, `Accessibility`, `Minors` |
| Priority | `Must`, `Should`, `Could` |

Tag usability-test findings with `UX-Law` and name the rule they break in the issue.

---

## 8. Releases

Version tags are lowercase `v` + semantic version:

| Tag | When |
|---|---|
| `v0.1.0` | Internal demo, Sun 11 Oct |
| `v0.2.0` | Optional, after usability test round 1 |
| `v1.0.0` | Final release, Sun 18 Oct |

```bash
git switch main && git pull
git tag -a v0.1.0 -m "Internal demo build"
git push origin v0.1.0
```
Pushing a tag builds a signed APK and attaches it to a GitHub Release.

---

## 9. Protected `main` (set up once by P2)

GitHub → Settings → Branches → add a rule for `main`:
- Require a pull request before merging (1 approval)
- Require status checks to pass
- Require conversation resolution
- Block force pushes and deletions

---

## 10. Secrets and data

- Never commit `.env`, API keys, Supabase service keys or model files.
- Use **test data only**. Real participant data never goes into Git, fixtures, screenshots or issues.
