# Field capture UI

Figma Screen Artboards 06.1 Hand over to participant (`3:2870`), 06.2
Participant reads consent (`3:2948`), 06.3 Participant answers by voice
(`3:2993`), 06.4 Consent choices (`3:3057`), 06.5 Sign, thumbprint or verbal
(`3:3129`), 06.6 Feedback pop-up (`3:3182`). Icons in `assets/icons/capture/`
were exported from Figma.

Routes (full screen, outside the tab shell): `/field-capture` (opened from a
project's "Start field capture" as `/field-capture?project=<id>`), then
`/read`, `/answer`, `/choices`, `/sign`, `/done`.

The **Capture tab** (`/capture`) is Figma 13.7, added 15 Oct 2026: the flow
needs a project, so the tab lists the projects that are collecting, with
search, a language filter and a Start field capture button on each. It
replaces the app-shell placeholder, and the dashboard's "Field capture"
quick action lands here too. 13.7 is new — it has no earlier artboard.

## Preview
`FIELD_CAPTURE_PREVIEW=true`, or any of `NEW_CONSENT_PREVIEW`,
`DASHBOARD_PREVIEW`, `PROJECTS_PREVIEW`.
- Sample participant P-065 (Kaera Tjiuma, Water access & health, Opuwo), 8
  consent sections, 4 questions and the 4 Figma choices.
- Nothing is saved or synced: the consent record store (P2) isn't connected.

Normal mode: "No participant session" and Start stays disabled.

## What is real and what is simulated
- Real: language choice, Large text (150% for the participant screens, or
  more if the phone is already larger), interpreter flag, voice answers
  through the phone's speech recogniser (`speech_to_text`), typing, the
  signature pad, witness name + signature, choices, feedback with voice
  dictation.
- Simulated until connected: read-aloud is timed but silent (recorded voice
  packs come with the offline pack); thumbprint counts a 1.2 s hold inside the
  frame; "Say it" times the recording but doesn't save audio.

## Rules
- System back does the same as the on-screen Back, so a participant doesn't
  drop out of the flow. The done screen can't go back.
- 06.4: Continue needs a Yes or No on every choice. No to "I agree to take
  part" finishes without signing.
- 06.5: Finish needs a signature, a captured thumbprint or a recording.
  Thumbprint and "Say it" also need a witness.
- 06.6: feedback is optional, kept apart from the consent answers and never
  asked of minors.

## Motion (Figma Animations page)
- Read-aloud highlight (4:18979): the spoken sentence is highlighted
  (#FFF1C2), the rest dim to 45%, the highlight glides 400 ms to the next one;
  tap a sentence to replay it.
- Voice listening (4:22683): mic breathes, halo pulses (2.4 s), waveform
  follows the voice level; stops instantly on tap.
- Consent capture (4:19275): ink follows the finger, Clear fades it; the
  thumbprint scan line sweeps and "Captured" pops; "Say it" pulses with a
  timer and waveform. The method pill slides 250 ms.
- Consent saved → feedback (4:22488): check pops with a soft burst, the
  thank-you rises in, then the pop-up scales in over the 45% scrim; the
  chosen face bounces.
- Reduce motion: fades only, no loops.
