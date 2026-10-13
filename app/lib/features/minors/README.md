# Minors: guardian consent + child assent

Figma Screen Artboards row 10: 10.1 Project setting (`3:6855`), 10.2 Age
check (`3:6928`), 10.3 Guardian details (`3:6966`), 10.4 Guardian consent
(`3:7029`), 10.5 Child assent 12–17 (`3:7074`), 10.6 Child assent 7–11
(`3:7132`), 10.7 Child said no (`3:7170`), 10.8 Minor consent record
(`3:7196`).

## Flow
Project ⋯ → Participants (`/participants/:id`, 10.1) turns minors on.
Field capture for that project then starts with the age check:

`/field-capture/age` → `guardian` → read the form (06.2, guardian mode) →
`guardian-consent` → `assent` (12–17 or 7–11 by age) → `done`, or `stopped`.

## Rules
- Under 18: guardian consent AND the young person's own assent.
- The band must be switched on in 10.1 (18+ is always on; under 7 never).
- The researcher confirms the guardian's legal authority (human-only).
- Guardian says No: the child isn't asked.
- Child says No: participation stops even though the guardian agreed;
  only "declined (assent)" is logged, no answers or recordings.
- "Not sure" pauses: Done stays off until Yes or No.
- The feedback pop-up is never shown to minors.
- 10.8 shows both decisions, the authority check and the re-consent date
  (their 18th birthday from the date of birth, or the latest it can be).

## Preview
`FIELD_CAPTURE_PREVIEW=true` (or `PROJECTS_PREVIEW`): the Water access &
health project includes 12–17 (FCI-REC-2026-041); age 14, guardian
Uerimunu Tjiuma, record P-071. Start from the project's "Start field
capture" (`/field-capture?project=water-opuwo`). Nothing is synced: the
record store (P2) and recorded voice packs aren't connected, so "Listen" is
timed but silent and the approval-letter upload explains it isn't
connected.

## Motion
Cards rise in, badges and the age number scale, the chosen face scales to
1.15 with a bounce (Figma 06.6 / 10.6), the listen button breathes while
playing, the authority check pops. Reduce motion: fades only.
