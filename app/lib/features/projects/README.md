# Projects UI

Figma Screen Artboards **03.3 Projects** (`3:1747`) and **03.4 Project detail**
(`3:1845`), 390 × 844. Icons in `assets/icons/projects/` were exported from Figma;
search, mic and chevron reuse the dashboard exports.

## Preview
`PROJECTS_PREVIEW=true` (or the existing `DASHBOARD_PREVIEW=true`) shows five
sample projects from Figma (the fifth, Closed, is added so every filter has a
result). Normal mode shows an honest empty state; no project data source exists yet.

## Behaviour
- Filter chips: All / Collecting / Drafts (includes Awaiting ethics) / Closed.
  The chip row scrolls sideways with large text or targets.
- Tap a card → `/projects/:id`. The detail is nested in the Projects tab, so the
  navbar stays and tapping Projects again returns to the list.
- Start field capture opens the Capture tab for Collecting projects only; other
  states explain why it's unavailable.
- Search, New project, card menus, export, share link/QR and the form card show a
  "will be connected" notice. Nothing is created, uploaded or exported.

## Motion (Figma Animations page)
- Navigation — push & back: detail slides in from the right, list shifts 25% left
  and dims; back (button, system back or a right swipe) reverses it. 350 ms
  easeOutCubic. Reduce motion: 150 ms fade.
- Cards fade/rise in 35 ms apart (stagger token); progress bars grow in 400 ms;
  chips change colour in 150 ms; dialogs scale 92% → 100%. All static or plain
  fades with Reduce motion.

## Not done
- Desktop artboard 09.2 / 09.3 (side rail layout) is not implemented here.
- Strings are hard-coded like the dashboard; move to l10n with the rest.
