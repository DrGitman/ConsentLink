// data/local/app_database.dart
// The app's local database. Open it with openLocalDatabase(), not directly.
import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Institutions,
    Profiles,
    Studies,
    ConsentSections,
    FormVersions,
    Participants,
    Consents,
    ConsentFiles,
    AuditLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// drift on top of the PowerSync (SQLCipher) database.
  AppDatabase(super.connection) : _createTables = false;

  /// For tests: any drift executor (e.g. NativeDatabase.memory()), with drift
  /// creating the tables itself because there is no PowerSync.
  AppDatabase.forTesting(super.executor) : _createTables = true;

  final bool _createTables;

  @override
  int get schemaVersion => 1;

  // PowerSync creates and updates the tables from powerSyncSchema, so drift
  // must never run CREATE TABLE on the real database.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      if (_createTables) await m.createAll();
    },
  );
}
