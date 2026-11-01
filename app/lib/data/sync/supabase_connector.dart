// data/sync/supabase_connector.dart
// PowerSync downloads what supabase/powersync/sync-rules.yaml allows. Uploads
// go to Supabase with the researcher's login, so RLS and the triggers decide.
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DriftSqlType, Value;
import 'package:powersync_sqlcipher/powersync.dart';
import 'package:supabase/supabase.dart';

import '../local/app_database.dart';

/// The Supabase calls the connector needs. Tests replace it with a fake.
abstract interface class SyncRemote {
  /// The signed-in researcher's access token, refreshed if needed. Null when
  /// nobody is signed in: PowerSync then waits instead of syncing.
  Future<String?> accessToken();
  Future<void> insert(String table, Map<String, dynamic> row);
  Future<void> update(String table, String id, Map<String, dynamic> changes);
  Future<void> delete(String table, String id);
  Future<bool> exists(String table, String id);
  Future<void> uploadFile(String path, Uint8List bytes, String contentType);
}

class SupabaseRemote implements SyncRemote {
  SupabaseRemote(this.client);
  final SupabaseClient client;

  @override
  Future<String?> accessToken() async {
    var session = client.auth.currentSession;
    if (session != null && session.isExpired) {
      session = (await client.auth.refreshSession()).session;
    }
    return session?.accessToken;
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> row) =>
      client.from(table).insert(row);

  @override
  Future<void> update(String table, String id, Map<String, dynamic> changes) =>
      client.from(table).update(changes).eq('id', id);

  @override
  Future<void> delete(String table, String id) =>
      client.from(table).delete().eq('id', id);

  @override
  Future<void> uploadFile(String path, Uint8List bytes, String contentType) =>
      client.storage
          .from('consent-files')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );

  @override
  Future<bool> exists(String table, String id) async =>
      await client.from(table).select('id').eq('id', id).maybeSingle() != null;
}

/// Postgres / PostgREST error codes that retrying can never fix: bad data
/// (22), a broken rule such as a wrong form hash or a minor without assent
/// (23, P0), no permission (42), or a request the API rejects (PGRST1/2).
/// Anything else (no signal, server down, expired login) is retried.
bool isPermanentUploadError(PostgrestException e) {
  final code = e.code ?? '';
  return const [
    '22',
    '23',
    '42',
    'P0',
    'PGRST1',
    'PGRST2',
  ].any(code.startsWith);
}

const _jsonColumns = {'changes', 'sections'};

class SupabaseConnector extends PowerSyncBackendConnector {
  SupabaseConnector({
    required this.remote,
    required this.local,
    required this.powerSyncUrl,
  }) : _boolColumns = {
         for (final t in local.allTables)
           t.actualTableName: {
             for (final c in t.$columns)
               if (c.type == DriftSqlType.bool) c.name,
           },
       };

  final SyncRemote remote;
  final AppDatabase local;
  final String powerSyncUrl;
  final Map<String, Set<String>> _boolColumns;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final token = await remote.accessToken();
    if (token == null) return null;
    return PowerSyncCredentials(endpoint: powerSyncUrl, token: token);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;
    for (final entry in transaction.crud) {
      await upload(entry);
    }
    await transaction.complete();
  }

  /// Sends one queued change. Throws (so PowerSync retries later) unless the
  /// change succeeded or was refused for good and kept in upload_failures.
  Future<void> upload(CrudEntry entry) async {
    final data = toServerRow(entry.table, entry.opData);
    try {
      if (entry.op == UpdateType.put && entry.table == 'consent_files') {
        if (!await _uploadFile(entry, data)) return;
      }
      switch (entry.op) {
        case UpdateType.put:
          await remote.insert(entry.table, {...data, 'id': entry.id});
        case UpdateType.patch:
          await remote.update(entry.table, entry.id, data);
        case UpdateType.delete:
          await remote.delete(entry.table, entry.id);
      }
    } on PostgrestException catch (e) {
      // Sent before but the reply was lost: the row is already there.
      if (entry.op == UpdateType.put &&
          e.code == '23505' &&
          await remote.exists(entry.table, entry.id)) {
        return;
      }
      if (!isPermanentUploadError(e)) rethrow;
      await _keep(entry, data, e.code, e.message);
    }
  }

  /// Uploads a consent file before its row. False if it was refused for good
  /// (kept in upload_failures) and the row must not be sent.
  Future<bool> _uploadFile(CrudEntry entry, Map<String, dynamic> data) async {
    final file = await (local.select(
      local.localFiles,
    )..where((f) => f.id.equals(entry.id))).getSingleOrNull();
    if (file == null) {
      await _keep(
        entry,
        data,
        'file_missing',
        'The file is not on this phone.',
      );
      return false;
    }
    try {
      await remote.uploadFile(
        file.storagePath,
        base64Decode(file.data),
        file.contentType,
      );
    } on StorageException catch (e) {
      final status = int.tryParse(e.statusCode ?? '') ?? 0;
      if (status == 409) return true; // uploaded before; reply was lost
      // An expired login (401), no signal or a busy server: try again later.
      if (status < 400 || status >= 500 || status == 401) rethrow;
      await _keep(entry, data, 'storage_$status', e.message);
      return false;
    }
    return true;
  }

  /// SQLite stores booleans as 1 / 0 and JSON as text; Supabase wants real ones.
  Map<String, dynamic> toServerRow(String table, Map<String, dynamic>? row) {
    final bools = _boolColumns[table] ?? const {};
    return {
      for (final MapEntry(:key, :value) in (row ?? const {}).entries)
        key: switch (value) {
          int v when bools.contains(key) => v != 0,
          String v when _jsonColumns.contains(key) => jsonDecode(v),
          _ => value,
        },
    };
  }

  Future<void> _keep(
    CrudEntry entry,
    Map<String, dynamic> data,
    String? code,
    String message,
  ) => local
      .into(local.uploadFailures)
      .insertOnConflictUpdate(
        UploadFailuresCompanion.insert(
          id: '${entry.table}/${entry.id}/${entry.clientId}',
          sourceTable: entry.table,
          rowId: entry.id,
          op: entry.op.json,
          data: Value(entry.opData == null ? null : jsonEncode(data)),
          errorCode: Value(code),
          errorMessage: message,
          failedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
}
