# Form builder UI

Figma Screen Artboards 04.5 Form builder (`3:2173`), 04.6 Add question
(`3:2309`) and 04.7 Template & style (`3:2394`). Icons in `assets/icons/form/`
were taken from the Figma vectors.

Routes: `/new-consent/form` (opened by "Continue to form builder" on 04.3) and
`/new-consent/template`.

- Fields follow `FormFieldDef { id, type, label, required, voiceAllowed,
  order, options }` from the shared contract (Figma Development Diagrams F).
- Drag the six-dot handle to reorder; tap a card or ··· to rename, toggle
  required/voice, duplicate or delete (confirm). Consent capture can't be
  deleted or made optional. The mic badge toggles voice answers.
- Add a question opens the 12-type sheet; the new card rises in.
- 04.7: pick a template (selected = 2 dp primary border); style values cross-
  fade. Official templates show the lock line and explain locked fields.
- Save form (preview) shows the "Form saved" toast and returns to Projects.

Preview data (sample fields and the three templates) only with
`NEW_CONSENT_PREVIEW`, `DASHBOARD_PREVIEW` or `PROJECTS_PREVIEW`. Normal mode
starts with the required consent-capture field and no templates.

Motion: sheets rise with a slight overshoot (400 ms easeOutBack), new cards
rise in (300 ms), lifted cards scale 1.03 while dragging, chips/borders 150 ms,
value swaps 250 ms, toasts slide up 16 dp. Reduce motion: fades only.
