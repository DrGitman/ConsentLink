# Settings, accessibility & account UI

Figma Screen Artboards 08.1 Me / settings (`3:3635`), 08.2 Accessibility
(`3:3735`), 08.3 Languages (`3:3809`), 08.4 Feedback pop-up settings
(`3:3891`), 08.5 Account & data (`3:3961`). New icons in
`assets/icons/settings/` were exported from Figma.

Routes: the Me tab (`/me`) shows 08.1; `/settings/accessibility`,
`/settings/languages`, `/settings/feedback`, `/settings/account`,
`/settings/privacy` are full screen. AI model opens the offline pack.

08.5 is split in two so nothing appears twice:
- **Account** (profile card): profile photo, researcher details (sheet to
  edit name, email, number, faculty, phone, supervisor, languages; shared
  with onboarding and saved on the phone), password & fingerprint, ethics
  clearances, sign out, delete account.
- **Privacy & data** (Privacy & data row): encryption, how long records are
  kept, download all my data, help.

Profile photo: camera or gallery (`image_picker`), resized to 512 px, saved
only on the phone (`consentlink.profilePhoto.v1`) and shown on the Me card.
Never added to consent records.

Ju/'hoansi (San) was added as a consent form and participant language after
the lecturer's feedback (15 Oct 2026, Figma 13.4 / 13.5). It also appears in
the app-language list, the first-run picker and the offline pack.

## Real, saved settings
Text size (app-wide, applied when you let go of the slider), high contrast,
read aloud + read-aloud speed (slider, 0.5–1.5×), larger targets, reduce
motion (app-wide, like the phone setting), dyslexia-friendly font, app
language and the feedback pop-up settings. Brightness and volume are left to
the phone. Saved with the other preferences.

Not applied yet: the dyslexia font (Atkinson Hyperlegible file isn't bundled)
and the dark appearance (not designed yet). Only English
is translated, so other app languages are saved but don't change the text.

## Preview
`SETTINGS_PREVIEW=true` or `DASHBOARD_PREVIEW` / `PROJECTS_PREVIEW`: the Figma
profile (Ndapewa Shikongo), form language states, model and sync numbers,
email and clearances. Normal mode shows "Your profile", English only and
"Not connected" states.

## Behaviour
- 08.3: tap On to turn a form language off (English stays on); Get downloads
  (simulated 2 s) and then needs review; Review asks a fluent reviewer to
  confirm.
- 08.4: field capture (06.6) honours it — off, never, first form then every
  n-th, or random about 1 in 3; voice comments hide the mic. Preview opens the
  real pop-up without saving.
- Delete account and Sign out ask first; account changes explain that the auth service
  isn't connected; Download all my data opens the export sheet.

## Motion
Rows rise in, radio dots pop, badges scale between states, sheets and dialogs
use the app motion; Reduce motion (system or app) turns it to fades.
