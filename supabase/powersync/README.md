# PowerSync (P2)

PowerSync sits between Supabase and the phones. Phones download through it
(only what `sync-rules.yaml` allows) and upload straight to Supabase with the
researcher's login, so RLS and the triggers check every upload.

## One-time setup (done on the live project)
1. **PowerSync instance** (dashboard.powersync.com), connected with the
   dashboard's **guided Supabase setup**. It creates PowerSync's own database
   user and the `powersync` publication, so nothing here needs running for that.
2. **Client auth:** Supabase Auth turned on, so PowerSync accepts the
   researchers' Supabase logins.
3. **Sync rules:** `sync-rules.yaml` pasted, validated and deployed.
   Redeploy it from the dashboard whenever this file changes.
4. **App:** the instance URL is `POWERSYNC_URL` (`app/lib/data/sync`).

`migrations/20261022000002_powersync_publication.sql` does not replace the
guided setup. It makes sure the publication exists and includes our tables,
for a new or reset database (e.g. `supabase db reset`), and on a project
where the guided setup already ran it only adds tables that are missing. It
never drops or narrows PowerSync's publication, and it is safe to run again.

Without the guided setup, PowerSync needs a database user with
`replication bypassrls login` and `select` on the synced tables. Give it a
long random password kept only in a password manager, never in Git or chat.

## Not synced yet
Language packs (`language_packs`, #72): phones should only get reviewed
content, but `participant_language_packs` is a view and PowerSync can't
follow views. Needs its own design.
