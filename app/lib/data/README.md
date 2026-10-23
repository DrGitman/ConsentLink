# data/ (P2)

The phone's own database: everything is saved here first, so the app works
with no internet. Sync to Supabase is added in `data/sync` (next step).

## Files
- `local/tables.dart`: the tables kept on the phone, mirroring
  `supabase/migrations`. A new server column is one line here.
- `local/powersync_schema.dart`: builds PowerSync's schema from those tables,
  so there is one list, not two. PowerSync creates the tables; drift queries them.
- `local/app_database.dart`: the drift database.
- `local/database_key.dart`: the encryption key (see below).
- `local/open_local_database.dart`: `openLocalDatabase()` opens it all.

## Encryption
The file is encrypted with SQLCipher. The key is made on the phone and kept in
the Android Keystore / iOS Keychain (see `local/database_key.dart`). `flutter
test` can't load SQLCipher, so tests use drift's in-memory SQLite.

## Generated code
drift generates `app_database.g.dart` (not in Git). After pulling, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```
