// data/local/open_local_database.dart
// Opens the encrypted local database. Works with no internet: PowerSync only
// talks to the server once sync is connected (data/sync, a later step).
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift_sqlite_async/drift_sqlite_async.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync_sqlcipher/powersync.dart';

import 'app_database.dart';
import 'database_key.dart';
import 'powersync_schema.dart';

const localDatabaseFileName = 'consentlink.db';

class LocalDatabase {
  LocalDatabase._(this.powerSync, this.drift);

  /// Used by sync (connect, upload queue, status).
  final PowerSyncDatabase powerSync;

  /// Used by repositories for typed queries.
  final AppDatabase drift;

  Future<void> close() async {
    await drift.close();
    await powerSync.close();
  }
}

/// [directory] is for tests; the app uses its private support directory.
Future<LocalDatabase> openLocalDatabase({
  KeyStore? keyStore,
  String? directory,
}) async {
  directory ??= (await getApplicationSupportDirectory()).path;
  final path = p.join(directory, localDatabaseFileName);
  final key = await loadOrCreateDatabaseKey(
    keyStore ?? SecureKeyStore(),
    databaseExists: File(path).existsSync(),
  );

  // drift's tables decide PowerSync's schema, so drift is made first and
  // connected once PowerSync is open.
  final opened = Completer<PowerSyncDatabase>();
  final drift = AppDatabase(
    DatabaseConnection.delayed(
      opened.future.then(SqliteAsyncDriftConnection.new),
    ),
  );
  final db = PowerSyncDatabase.withFactory(
    PowerSyncSQLCipherOpenFactory(path: path, key: key),
    schema: powerSyncSchemaFor(drift),
  );
  await db.initialize();
  opened.complete(db);
  return LocalDatabase._(db, drift);
}
