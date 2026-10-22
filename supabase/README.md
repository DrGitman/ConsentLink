# supabase/ (P2)

Cloud database for ConsentLink: tables, access rules and seed data.

## Files
- `migrations/20261016000001_init.sql` creates everything. Run it once on a new Supabase project (Dashboard, SQL Editor).
- `seed.sql` adds two development institutions (NUST, UNAM). Run it after the migration.

## What the database enforces (not the app)
- Each institution sees only its own rows (row-level security).
- New accounts join the institution that owns their confirmed email domain. No match, no access.
- The audit log is append-only for everyone, including admins and `service_role`. The server writes the entries for study created, section approved, form published, consent signed and consent withdrawn. The app may only add `consent_exported`.
- A published form is a frozen snapshot. The server recomputes its fingerprint (same rule as `app/lib/contracts/form_hash.dart`) and rejects a wrong one.
- A consent must match a published form version and hash.
- A minor's Yes needs guardian consent and the child's own assent. A child's No always wins.
- A withdrawal sets `withdrawn_at` and can never be changed or undone. Consents cannot be deleted.

## Languages
`languages.code` is the stored value: a BCP 47 code (`en`, `af`, `de`, `hz`, `naq`, `ktz`, `kwn`, `loz`, `ng`, `kj`). Display names and spelling (Juǀ'hoansi, with U+01C0) live in `app/lib/contracts/languages.dart` only. That file and the table must list the same codes. A new language is one entry there and one INSERT here.

## Notes for sync (task 4)
- Ids are UUIDs made on the device. `institution_id` on child rows is set by the server.
- The local audit table must not try to upload anything except `consent_exported`.
