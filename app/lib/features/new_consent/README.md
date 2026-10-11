# New consent (AI drafting) UI

Figma Screen Artboards 04.1 Upload proposal (`3:1940`), 04.2 AI analysing
(`3:1990`), 04.3 Review AI draft (`3:2033`), 04.4 Why did AI write this?
(`3:2122`). Icons in `assets/icons/consent/` were exported from Figma.

Routes (full screen, outside the tab shell): `/new-consent`,
`/new-consent/drafting`, `/new-consent/review`. Opened from the Dashboard
"New consent" quick action and the Projects + button.

## Preview
`NEW_CONSENT_PREVIEW=true`, `DASHBOARD_PREVIEW=true` or `PROJECTS_PREVIEW=true`.
- Tapping the drop zone offers two sample files: a safe 18-page PDF and a blocked
  `.exe`. Nothing is read, scanned or uploaded.
- Analyse runs a 4.2 s scripted drafting sequence, then opens the Figma 04.3 draft.
- No AI model runs. P3's on-device model and P4's scan service will drive the
  same states later (`ConsentDraftController`).

Normal mode: the drop zone explains that upload isn't connected, and Analyse
stays disabled.

## Behaviour (04.3 / 04.4)
- 10 required elements; the complaints contact is missing until you tap the
  amber checklist. Approved + edited sections count towards "N of 10 approved";
  the footer button enables at 10/10.
- Approve (card or sheet) logs "Logged: approved by <name>, <date time>" and shows
  an in-app Undo toast (institution colour, 5 s). Edit opens a text sheet; saving marks the section Edited.
- Otjiherero chip: shows a note that translation must be checked by a fluent
  reviewer and isn't generated in the preview.
- Preview (document icon), Describe instead, Simplify, Open page and Continue show
  "will be connected" notices.

## Motion (Figma Animations page)
- Upload & file scan: file card rises in, uploading bar, scanning spinner,
  "Scanned · safe" pops, Analyse colour tweens on; blocked card slides in, turns
  red and shakes once.
- AI drafting — progress: orb halo breathes (1.2 s), steps tick with a drawn,
  popping check, bar fills.
- Approve section: badge morphs AI draft → Approved, green border flash, themed Undo toast 5 s.
- Upload icon lifts and pulses in a loop while visible; AI orb twinkles, breathes
  and ripples.
- Sheets rise with a slight overshoot (easeOutBack 400 ms) over a fading scrim;
  dialogs scale 92% → 100%.
- Reduce motion: no breathing, shake, slide or pop; 150 ms fades only.

## Data shape
`DraftSection` uses the agreed AI output from Figma Development Diagrams,
frame G (`schemas/consent_draft`) and the `Section` contract in frame F:
`key, title, text, sourcePages, sourceQuote, changes, confidence ("high" |
"medium" | "low"), aiGenerated, readingGrade, approvedBy, approvedAt`.
Keys are the 10 required elements from G (`requiredElementKeys`); the 4 minors
keys are listed in `minorsElementKeys` for the rule checker (P3).
