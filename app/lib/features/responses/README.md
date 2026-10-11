# Responses, analytics & export UI

Figma Screen Artboards 07.1 Responses (`3:3274`), 07.2 Consent record
(`3:3384`), 07.3 Analytics (`3:3440`), 07.4 Export (`3:3561`), 07.5 Withdraw
confirmation (`4:18913`). Icons in `assets/icons/responses/` were exported
from Figma.

Routes: `/insights` (Insights tab, 07.3) and `/insights/responses` (07.1,
opened by tapping the recruitment card) inside the tab shell;
`/responses/<code>` (07.2) full screen. The export sheet (07.4) opens from the
Insights and record download buttons and from Project detail.

## Preview
`INSIGHTS_PREVIEW=true`, `DASHBOARD_PREVIEW=true` or `PROJECTS_PREVIEW=true`.
- 69 sample responses (64 agreed, 3 declined, 2 withdrew); the six newest are
  the Figma rows. Today's three are "waiting to sync".
- Insights numbers for 7 days, 30 days (Figma) and all time.
- Export runs for 1.2 s, is logged, and the toast says no file was saved.
  File writing and project storage (P2) aren't connected yet.

Normal mode: "No responses yet" / "No insights yet", export disabled.

## Behaviour
- 07.1: filter chips with live counts, search by name or code, sort & filter
  sheet (newest/oldest, only waiting to sync). Tap a card for its record.
- 07.2: answers, signature + witness, audit trail. Declined records have no
  signature and no withdraw button.
- 07.5: Withdraw marks the record Withdrew, adds an audit entry and shows a
  toast. Cancel or tapping outside changes nothing.

## Motion (Figma Animations page)
- Navigation — sheet & dialog (4:19150): sheet rises with a slight overshoot
  over a 45% scrim; the dialog scales 92% → 100% with a fade.
- Cards rise in 35 ms apart; filter changes cross-fade.
- Insights: bars grow from the bottom 20 ms apart, numbers count up, language
  bars fill, all again when the period changes.
- Reduce motion: fades only, no growth or count-up.
