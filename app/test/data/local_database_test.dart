import 'package:consentlink/data/local/app_database.dart';
import 'package:consentlink/data/local/database_key.dart';
import 'package:consentlink/data/local/powersync_schema.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync_sqlcipher/powersync.dart' as ps;

class _MapKeyStore implements KeyStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async => values[name] = value;
}

void main() {
  test('PowerSync gets every drift table and column, typed for SQLite', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final schema = powerSyncSchemaFor(db).tables;
    final tables = {
      for (final t in schema)
        t.name: {for (final c in t.columns) c.name: c.type},
    };
    expect(
      [
        for (final t in schema)
          if (t.localOnly) t.name,
      ],
      ['upload_failures'],
      reason: 'only the failure log stays on the phone',
    );
    expect(tables.keys, containsAll(['studies', 'consents', 'audit_log']));
    expect(tables.length, 10);
    expect(tables['consents']!['child_assent'], ps.ColumnType.integer);
    expect(tables['consents']!['withdrawal_reason'], ps.ColumnType.text);
    expect(tables['consent_sections']!['text'], ps.ColumnType.text);
    expect(tables['consent_sections']!['order'], ps.ColumnType.integer);
    expect(
      tables['studies']!.containsKey('id'),
      isFalse,
      reason: 'PowerSync adds id itself',
    );
  });

  group('local database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a consent made offline saves and reads back', () async {
      await db
          .into(db.consentSections)
          .insert(
            ConsentSectionsCompanion.insert(
              id: 'c1',
              studyId: 's1',
              order: 0,
              language: 'ktz',
              body: 'Juǀ\'hoansi text',
              status: 'approved',
            ),
          );
      await db
          .into(db.consents)
          .insert(
            ConsentsCompanion.insert(
              id: 'k1',
              studyId: 's1',
              participantId: 'p1',
              language: 'ktz',
              decision: 'no',
              method: 'verbal',
              guardianConsent: const Value(true),
              childAssent: const Value(false),
              formVersion: 1,
              formHash: 'abc',
              signedAt: '2026-10-22T08:00:00.000Z',
            ),
          );

      final consent = await db.select(db.consents).getSingle();
      expect(consent.childAssent, isFalse);
      expect(consent.guardianConsent, isTrue);
      expect(consent.institutionId, isNull, reason: 'set by the server');
      expect(consent.receivedAt, isNull, reason: 'not synced yet');

      final section = await db.select(db.consentSections).getSingle();
      expect(section.body, 'Juǀ\'hoansi text');
      expect(section.changes, '[]');
    });
  });

  group('database key', () {
    test('a fresh install makes a random 256-bit key and keeps it', () async {
      final store = _MapKeyStore();
      final key = await loadOrCreateDatabaseKey(store, databaseExists: false);
      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(store.values[databaseKeyName], key);
      expect(
        await loadOrCreateDatabaseKey(store, databaseExists: true),
        key,
        reason: 'the same key is used every time after',
      );
    });

    test('a lost key is reported, never silently replaced', () async {
      final store = _MapKeyStore();
      await expectLater(
        loadOrCreateDatabaseKey(store, databaseExists: true),
        throwsA(isA<DatabaseKeyMissing>()),
      );
      expect(store.values, isEmpty);
    });
  });
}
