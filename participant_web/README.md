# Participant page (share link / QR code)

The page a participant opens from a ConsentLink share link or QR code
(03.4 "Share link / QR code"). Plain HTML and JavaScript, no build step.

## Set up once

1. Apply `supabase/migrations/20261102000001_consent_links.sql` to the
   Supabase project (P2).
2. Host this folder over HTTPS. With GitHub Pages: Settings, Pages, deploy
   from the default branch, root folder. The page is then at
   `https://drgitman.github.io/ConsentLink/participant_web/`.
3. Build the app with that address if it is different:
   `--dart-define=CONSENT_LINK_BASE_URL=https://.../participant_web/`

`config.js` holds the Supabase URL and the publishable key. The page can only
call `link_form` and `link_submit`; both check the link every time.

## What the participant can do

Read the published form in any language it has in full, hear it read aloud
where the browser has a voice, choose yes or no, and sign with a finger.
Studies with minors are not offered by link: guardian consent and the child's
own assent are taken in person.
