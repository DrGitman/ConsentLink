import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:consentlink/contracts/models.dart';
import 'package:consentlink/data/export/consent_export_service.dart';
import 'package:consentlink/data/local/app_database.dart' show AppDatabase;
import 'package:consentlink/data/repositories/drift_consent_repository.dart';
import 'package:consentlink/data/repositories/drift_study_repository.dart';
import 'package:consentlink/data/sync/supabase_connector.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync_sqlcipher/powersync.dart';
import 'package:supabase/supabase.dart';

/// A 1×1 PNG, as a signature pad would save.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==',
);

class _Remote implements SyncRemote {
  final calls = <String>[];
  Object? fileFail;
  @override
  Future<String?> accessToken() async => 'jwt';
  @override
  Future<void> uploadFile(String path, Uint8List bytes, String type) async {
    calls.add('file $type');
    if (fileFail != null) throw fileFail!;
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> row) async =>
      calls.add('insert $table');
  @override
  Future<void> update(String t, String id, Map<String, dynamic> c) async {}
  @override
  Future<void> delete(String table, String id) async {}
  @override
  Future<bool> exists(String table, String id) async => false;
}

void main() {
  late AppDatabase db;
  late DriftParticipantRepository participants;
  late Consent consent;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final studies = DriftStudyRepository(db);
    participants = DriftParticipantRepository(db);
    var study = await studies.createStudy(
      const StudyDraft(title: 'T', involvesMinors: false),
    );
    await studies.saveSection(
      ConsentSection(
        id: 's1',
        studyId: study.id,
        order: 0,
        language: 'en',
        text: 'Purpose',
        status: SectionStatus.draft,
      ),
    );
    await studies.approveSection('s1');
    study = await studies.publishForm(study.id);
    final p = await participants.create(
      ParticipantDraft(studyId: study.id, language: 'en', isMinor: false),
    );
    consent = await DriftConsentRepository(db).saveConsent(
      ConsentDraft(
        studyId: study.id,
        participantId: p.id,
        language: 'en',
        decision: ConsentDecision.yes,
        method: ConsentMethod.signature,
        formVersion: study.formVersion,
        formHash: study.formHash!,
      ),
    );
  });
  tearDown(() => db.close());

  test('a signature is kept on the phone with its SHA-256', () async {
    await participants.storeSignature(
      consent.id,
      SignatureKind.signature,
      _png,
    );
    final row = await db.select(db.consentFiles).getSingle();
    expect(row.sha256, sha256.convert(_png).toString());
    expect(row.storagePath, startsWith('${consent.studyId}/${consent.id}/'));
    final files = await participants.signatureFiles(consent.id);
    expect(files.single.$1, SignatureKind.signature);
    expect(files.single.$2, _png);
    await expectLater(
      participants.storeSignature('nope', SignatureKind.audio, _png),
      throwsStateError,
    );
  });

  group('sync', () {
    late _Remote remote;
    late SupabaseConnector connector;
    late CrudEntry put;
    setUp(() async {
      await participants.storeSignature(
        consent.id,
        SignatureKind.signature,
        _png,
      );
      final row = await db.select(db.consentFiles).getSingle();
      remote = _Remote();
      connector = SupabaseConnector(
        remote: remote,
        local: db,
        powerSyncUrl: '',
      );
      put = CrudEntry(1, UpdateType.put, 'consent_files', row.id, 1, {
        'storage_path': row.storagePath,
      });
    });

    test('uploads the file before its row', () async {
      await connector.upload(put);
      expect(remote.calls, ['file image/png', 'insert consent_files']);
    });

    test('a file already in Storage counts as uploaded', () async {
      remote.fileFail = const StorageException('Duplicate', statusCode: '409');
      await connector.upload(put);
      expect(remote.calls.last, 'insert consent_files');
    });

    test('a refused or missing file is kept and its row not sent', () async {
      remote.fileFail = const StorageException('Forbidden', statusCode: '403');
      await connector.upload(put);
      await (db.delete(db.localFiles)).go();
      await connector.upload(
        CrudEntry(2, UpdateType.put, 'consent_files', put.id, 2, put.opData),
      );
      final kept = await db.select(db.uploadFailures).get();
      expect(kept.map((k) => k.errorCode), ['storage_403', 'file_missing']);
      expect(remote.calls, isNot(contains('insert consent_files')));
    });

    test('a server or login problem is retried later', () async {
      for (final status in ['500', '401']) {
        remote.fileFail = StorageException('Busy', statusCode: status);
        await expectLater(
          connector.upload(put),
          throwsA(isA<StorageException>()),
        );
      }
      expect(await db.select(db.uploadFailures).get(), isEmpty);
    });
  });

  test('the PDF export shows the signature image', () async {
    await participants.storeSignature(
      consent.id,
      SignatureKind.signature,
      _png,
    );
    Future<ByteData> font(String name) async =>
        ByteData.sublistView(await File('assets/fonts/$name').readAsBytes());
    final pdf = await ConsentExportService(
      studies: DriftStudyRepository(db),
      consents: DriftConsentRepository(db),
      audit: DriftAuditRepository(db),
      fonts: () async =>
          (await font('Inter-Regular.ttf'), await font('Inter-SemiBold.ttf')),
      signatures: participants.signatureFiles,
    ).consentPdf(consent.id);
    expect(latin1.decode(pdf).contains('/Subtype/Image'), isTrue);
  });
}
