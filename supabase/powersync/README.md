# PowerSync (P2)

PowerSync sits between Supabase and the phones. Phones download through it
(only what `sync-rules.yaml` allows) and upload straight to Supabase with the
researcher's login, so RLS and the triggers check every upload.

## One-time setup
Do these after `migrations/20261016000001_init.sql` is applied.

1. **Database user for PowerSync.** In the Supabase SQL Editor, choose a long
   random password (keep it in a password manager, never in Git or chat):
   ```sql
   create role powersync_role with replication bypassrls login password '<password>';
   grant select on public.institutions, public.profiles, public.studies,
     public.consent_sections, public.form_versions, public.participants,
     public.consents, public.consent_files, public.audit_log to powersync_role;
   ```
   PowerSync needs `bypassrls` to read changes. Phones still only get what the
   sync rules allow.
2. **Publication.** Run `migrations/20261022000002_powersync_publication.sql`.
3. **PowerSync instance** (dashboard.powersync.com): create an instance and
   connect it to Supabase with `powersync_role`, the password above and SSL on.
   Turn on **Supabase Auth** for client authentication so PowerSync accepts
   the researchers' Supabase logins.
4. **Sync rules.** Paste `sync-rules.yaml`, validate, deploy.
5. **App.** Copy the instance URL. The app takes it as `POWERSYNC_URL`
   (`app/lib/data/sync`, separate PR).

## Not synced yet
Language packs (`language_packs`, #72): phones should only get reviewed
content, but `participant_language_packs` is a view and PowerSync can't
follow views. Needs its own design.
