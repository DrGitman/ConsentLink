# Template Studio UI

Figma Screen Artboards 05.1 Template library (`79:2`), 05.2 Detected template
styles (`3:2571`), 05.3 Clip logo from PDF (`3:2653`), 05.4 Describe a
template (`3:2714`), 05.5 Template detail (`79:121`), 05.6 Save & share
(`79:209`). New icons in `assets/icons/templates/` (crop, copy) were exported
from Figma.

Lecturer feedback (15 Oct 2026), Figma row 13: a template's sections (its
structure and wording) can be read on any template and changed in your own
copy — 13.1 Template library — Shared tab (`174:42`), 13.2 Shared template —
contents + Use as my template (`175:434`), 13.3 Customise a shared template
(`174:153`), 13.6 Edit a section (`180:603`).

Routes (full screen, outside the tab shell): `/templates` (from the Dashboard
"Templates" quick action), `/templates/read`, `/templates/clip`,
`/templates/describe`, `/templates/view/<id>`,
`/templates/customise/<id>`. 05.6 is a sheet.

## Preview
`TEMPLATES_PREVIEW=true` or any of the existing preview flags.
- The four Figma templates (private, two official NUST, one shared).
- Upload reads the sample `NUST_HREC_consent_2026.docx`: 1.2 s scan, then the
  five detected rules. Nothing is read, scanned or uploaded.
- The assistant's replies are scripted; the on-device model (P3) isn't
  connected. Voice input uses the phone's recogniser (dictation sheet).
- Saved templates stay in memory until template storage (P2) is connected.

Normal mode: "No templates yet"; Upload explains it isn't connected and the
assistant is disabled.

## Behaviour
- 05.1: + makes a blank template; Upload picks a file (sheet) then 05.2;
  Describe opens 05.4. All / Mine / Shared / Official, search by name or owner (type or speak).
- 05.2: tap a rule to change it (badge becomes "Edited"); tap the logo card to
  clip it; Save template opens 05.6.
- 05.3: drag the box to move it, drag a corner to resize; Auto-detect snaps it
  back to the logo; Remove white background changes the saved format.
- 05.4: untick anything you don't want; sending a message adds a new proposal
  with the ticked items plus your request; Create template opens 05.6.
- 05.5: official templates are locked (font, footer, logo); your own can be
  edited, renamed or deleted (⋯). Duplicate makes a private copy. Use for
  form opens Template & style (04.7) for templates the form builder knows.
- 05.5 / 13.2: a shared template is read-only, so its one action is **Use as
  my template**; official templates offer the same from ⋯.
- 13.2: every template shows **What's inside** — its sections, with the
  first line of each. Tapping one opens it; on a template that isn't yours
  it opens read-only, and official wording stays locked.
- 13.3: name the copy, reword or rename its sections (13.6), switch optional
  ones off, add your own, change the style rules, then Save as my template.
  The 10 required consent elements can't be switched off. The copy is
  private, carries "Customised from <original>", and the shared original is
  never changed.
- Your own templates (05.5) edit their sections in place.
- 05.6: name (type or speak) and who can use it: only me, institution
  researchers, or request Official status.

## Motion
- Upload & file scan: scanning badge, then "Safe · macros removed" pops and
  the rules rise in 35 ms apart.
- Clip: the crop box glides back when Auto-detect snaps it.
- Assistant: messages rise in, typing dots bounce, checkboxes pop.
- Sheets rise with the app's sheet motion; radio dots pop.
- Reduce motion: fades only, no loops.
