import 'dart:io';

import 'package:consentlink/data/local/app_database.dart';
import 'package:consentlink/data/sync/supabase_connector.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync_sqlcipher/powersync.dart';
import 'package:supabase/supabase.dart';

class _FakeRemote implements SyncRemote {
  String? token = 'jwt';
  final calls = <String>[];
  final rows = <String, Map<String, dynamic>>{};
  Object? fail;

  void _maybeFail() {
    final f = fail;
    if (f != null) throw f;
  }

  @override
  Future<String?> accessToken() async => token;
  @override
  Future<void> insert(String table, Map<String, dynamic> row) async {
    calls.add('insert $table');
    _maybeFail();
    rows['$table/${row['id']}'] = row;
  }

  @override
  Future<void> update(String table, String id, Map<String, dynamic> c) async {
    calls.add('update $table $id $c');
    _maybeFail();
  }

  @override
  Future<void> delete(String table, String id) async => _maybeFail();
  @override
  Future<bool> exists(String table, String id) async =>
      rows.containsKey('$table/$id');
}

CrudEntry _put(String table, String id, Map<String, dynamic> data) =>
    CrudEntry(1, UpdateType.put, table, id, 1, data);

void main() {
  late AppDatabase local;
  late _FakeRemote remote;
  late SupabaseConnector connector;
  setUp(() {
    local = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _FakeRemote();
    connector = SupabaseConnector(
      remote: remote,
      local: local,
      powerSyncUrl: 'https://ps.example',
    );
  });
  tearDown(() => local.close());

  final consent = {
    'study_id': 's1',
    'participant_id': 'p1',
    'decision': 'no',
    'guardian_consent': 1,
    'child_assent': 0,
    'form_version': 1,
  };

  test('signed out: no credentials, so PowerSync waits', () async {
    remote.token = null;
    expect(await connector.fetchCredentials(), isNull);
    remote.token = 'jwt';
    final c = (await connector.fetchCredentials())!;
    expect((c.endpoint, c.token), ('https://ps.example', 'jwt'));
  });

  test('a new consent is inserted with real booleans', () async {
    await connector.upload(_put('consents', 'k1', consent));
    final sent = remote.rows['consents/k1']!;
    expect(sent['id'], 'k1');
    expect(sent['guardian_consent'], isTrue);
    expect(sent['child_assent'], isFalse);
    expect(sent['form_version'], 1, reason: 'integers stay integers');
  });

  test('JSON columns are sent as JSON, not text', () {
    final row = connector.toServerRow('consent_sections', {
      'changes': '["shortened"]',
      'text': '["not json"]',
    });
    expect(row['changes'], ['shortened']);
    expect(row['text'], '["not json"]');
  });

  test('a change only sends the changed columns', () async {
    await connector.upload(
      CrudEntry(2, UpdateType.patch, 'consents', 'k1', 2, {
        'withdrawn_at': '2026-10-22T09:00:00Z',
      }),
    );
    expect(
      remote.calls.single,
      contains('{withdrawn_at: 2026-10-22T09:00:00Z}'),
    );
  });

  test('re-sending a row the server already has is not an error', () async {
    remote.rows['consents/k1'] = {'id': 'k1'};
    remote.fail = const PostgrestException(message: 'dup', code: '23505');
    await connector.upload(_put('consents', 'k1', consent));
    expect(await local.select(local.uploadFailures).get(), isEmpty);
  });

  test('a refused consent is kept on the phone with the reason', () async {
    remote.fail = const PostgrestException(
      message:
          "a Yes for a minor needs guardian consent and the child's own assent",
      code: 'P0001',
    );
    await connector.upload(_put('consents', 'k1', consent));
    final kept = await local.select(local.uploadFailures).getSingle();
    expect((kept.sourceTable, kept.rowId, kept.op), ('consents', 'k1', 'PUT'));
    expect(kept.errorCode, 'P0001');
    expect(kept.data, contains('"child_assent":false'));
  });

  for (final (name, error) in [
    ('no signal', const SocketException('offline')),
    (
      'expired login',
      const PostgrestException(message: 'JWT expired', code: 'PGRST303'),
    ),
    (
      'server busy',
      const PostgrestException(message: 'timeout', code: '57014'),
    ),
  ]) {
    test('$name: retried later, nothing marked as failed', () async {
      remote.fail = error;
      await expectLater(
        connector.upload(_put('consents', 'k1', consent)),
        throwsA(same(error)),
      );
      expect(await local.select(local.uploadFailures).get(), isEmpty);
    });
  }
}
