// data/local/database_key.dart
// The SQLCipher key for the local database.
//
// The key is 32 random bytes made on the phone the first time the app opens
// its database. It is kept in the platform keystore (Android Keystore / iOS
// Keychain) through flutter_secure_storage, never in code, logs or Git.
// Without it the database file cannot be read.
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the key is kept. The real one is [SecureKeyStore]; tests use a map.
abstract interface class KeyStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
}

class SecureKeyStore implements KeyStore {
  SecureKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);
}

const databaseKeyName = 'consentlink_db_key_v1';

/// The database file exists but its key is gone (e.g. the keystore was reset).
/// We never make a new key over an old file: that would hide, not fix, the
/// loss of any consents not yet synced.
class DatabaseKeyMissing implements Exception {
  @override
  String toString() =>
      'The local database key is missing, so the existing database cannot be '
      'opened. It has not been deleted.';
}

/// Returns the key, making and saving one if this is a fresh install.
/// [databaseExists] says whether a database file is already on the phone.
Future<String> loadOrCreateDatabaseKey(
  KeyStore store, {
  required bool databaseExists,
}) async {
  final existing = await store.read(databaseKeyName);
  if (existing != null) return existing;
  if (databaseExists) throw DatabaseKeyMissing();

  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await store.write(databaseKeyName, key);
  return key;
}
