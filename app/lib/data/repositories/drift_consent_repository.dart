// data/repositories/drift_consent_repository.dart
// Consent, participant and audit repositories on the local database. Sync
// uploads the records and the server checks them again.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:powersync_sqlcipher/powersync.dart' as ps;
import 'package:uuid/uuid.dart';

import '../../contracts/audit_repository.dart';
import '../../contracts/consent_repository.dart';
import '../../contracts/models.dart';
import '../../contracts/participant_repository.dart';
import '../local/app_database.dart' as db;

class DriftConsentRepository implements ConsentRepository {
  DriftConsentRepository(this._db, {this.sync, this.now = DateTime.now});
  final db.AppDatabase _db;

  /// Null when sync is off (status: offline).
  final ps.PowerSyncDatabase? sync;
  final DateTime Function() now;

  @override
  Future<Consent> saveConsent(ConsentDraft draft) async {
    final form =
        await (_db.select(_db.formVersions)..where(
              (f) =>
                  f.studyId.equals(draft.studyId) &
                  f.version.equals(draft.formVersion) &
                  f.formHash.equals(draft.formHash),
            ))
            .getSingleOrNull();
    if (form == null) {
      throw StateError('The consent does not match a published form version.');
    }
    final participant = await (_db.select(
      _db.participants,
    )..where((p) => p.id.equals(draft.participantId))).getSingleOrNull();
    if (participant == null || participant.studyId != draft.studyId) {
      throw StateError('Unknown participant for this study.');
    }
    final guardian = draft.guardianConsent, assent = draft.childAssent;
    if (participant.isMinor &&
        (guardian == null ||
            assent == null ||
            (draft.decision == ConsentDecision.yes && !(guardian && assent)))) {
      throw StateError('A minor needs guardian consent and assent.');
    }
    final id = const Uuid().v4();
    await _db
        .into(_db.consents)
        .insert(
          db.ConsentsCompanion.insert(
            id: id,
            studyId: draft.studyId,
            participantId: draft.participantId,
            language: draft.language,
            decision: draft.decision.name,
            method: draft.method.name,
            witnessName: Value(draft.witnessName),
            interpreterName: Value(draft.interpreterName),
            guardianConsent: Value(draft.guardianConsent),
            childAssent: Value(draft.childAssent),
            formVersion: draft.formVersion,
            formHash: draft.formHash,
            signedAt: now().toUtc().toIso8601String(),
          ),
        );
    return (await getConsent(id))!;
  }

  @override
  Future<Consent?> getConsent(String id) async {
    final row = await (_db.select(
      _db.consents,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toConsent(row);
  }

  @override
  Future<List<Consent>> listByStudy(String studyId) async {
    final rows =
        await (_db.select(_db.consents)
              ..where((c) => c.studyId.equals(studyId))
              ..orderBy([(c) => OrderingTerm.desc(c.signedAt)]))
            .get();
    return rows.map(_toConsent).toList();
  }

  @override
  Future<void> withdraw(String consentId, String reason) async {
    final consent = await getConsent(consentId);
    if (consent == null) throw StateError('No consent $consentId');
    if (consent.withdrawnAt != null) {
      throw StateError('A withdrawal cannot be changed or undone.');
    }
    await (_db.update(
      _db.consents,
    )..where((c) => c.id.equals(consentId))).write(
      db.ConsentsCompanion(
        withdrawnAt: Value(now().toUtc().toIso8601String()),
        withdrawalReason: Value(reason),
      ),
    );
  }

  @override
  Stream<SyncStatus> watchSyncStatus() {
    final sync = this.sync;
    if (sync == null) return Stream.value(SyncStatus.offline);
    return sync.statusStream.map(
      (s) => s.anyError != null
          ? SyncStatus.error
          : !s.connected
          ? SyncStatus.offline
          : s.uploading || s.downloading
          ? SyncStatus.syncing
          : SyncStatus.synced,
    );
  }

  Consent _toConsent(db.Consent row) => Consent.fromJson({
    'id': row.id,
    'study_id': row.studyId,
    'participant_id': row.participantId,
    'language': row.language,
    'decision': row.decision,
    'method': row.method,
    'witness_name': row.witnessName,
    'interpreter_name': row.interpreterName,
    'guardian_consent': row.guardianConsent,
    'child_assent': row.childAssent,
    'form_version': row.formVersion,
    'form_hash': row.formHash,
    'signed_at': row.signedAt,
    'received_at': row.receivedAt,
    'withdrawn_at': row.withdrawnAt,
    'withdrawal_reason': row.withdrawalReason,
  });
}

class DriftParticipantRepository implements ParticipantRepository {
  DriftParticipantRepository(this._db);
  final db.AppDatabase _db;

  @override
  Future<Participant> create(ParticipantDraft draft) async {
    final id = const Uuid().v4();
    await _db
        .into(_db.participants)
        .insert(
          db.ParticipantsCompanion.insert(
            id: id,
            studyId: draft.studyId,
            language: draft.language,
            isMinor: draft.isMinor,
            createdAt: Value(DateTime.now().toUtc().toIso8601String()),
          ),
        );
    return Participant(
      id: id,
      studyId: draft.studyId,
      language: draft.language,
      isMinor: draft.isMinor,
    );
  }

  /// Kept in the encrypted database and listed in consent_files with its
  /// SHA-256. Sync uploads the file to Storage (bucket consent-files, under
  /// study/consent/) before the row, so the row never points at nothing.
  @override
  Future<void> storeSignature(
    String consentId,
    SignatureKind kind,
    Uint8List data,
  ) async {
    final consent = await (_db.select(
      _db.consents,
    )..where((c) => c.id.equals(consentId))).getSingleOrNull();
    if (consent == null) throw StateError('No consent $consentId');
    final id = const Uuid().v4();
    final audio = kind == SignatureKind.audio;
    final path = '${consent.studyId}/$consentId/$id.${audio ? 'audio' : 'png'}';
    await _db.transaction(() async {
      await _db
          .into(_db.localFiles)
          .insert(
            db.LocalFilesCompanion.insert(
              id: id,
              storagePath: path,
              contentType: audio ? 'application/octet-stream' : 'image/png',
              data: base64Encode(data),
            ),
          );
      await _db
          .into(_db.consentFiles)
          .insert(
            db.ConsentFilesCompanion.insert(
              id: id,
              consentId: consentId,
              studyId: consent.studyId,
              kind: kind.name,
              storagePath: path,
              sha256: sha256.convert(data).toString(),
              createdAt: Value(DateTime.now().toUtc().toIso8601String()),
            ),
          );
    });
  }

  /// The files of a consent that are on this phone (for the PDF export).
  Future<List<(SignatureKind, Uint8List)>> signatureFiles(
    String consentId,
  ) async {
    final query = _db.select(_db.consentFiles).join([
      innerJoin(
        _db.localFiles,
        _db.localFiles.id.equalsExp(_db.consentFiles.id),
      ),
    ])..where(_db.consentFiles.consentId.equals(consentId));
    final fromLink = await (_db.select(
      _db.linkSignatures,
    )..where((s) => s.id.equals(consentId))).getSingleOrNull();
    return [
      for (final row in await query.get())
        (
          SignatureKind.values.byName(row.readTable(_db.consentFiles).kind),
          base64Decode(row.readTable(_db.localFiles).data),
        ),
      // Signed on the participant's own phone through a share link.
      if (fromLink != null)
        (SignatureKind.signature, base64Decode(fromLink.pngBase64)),
    ];
  }
}

class DriftAuditRepository implements AuditRepository {
  DriftAuditRepository(this._db, {this.now = DateTime.now});
  final db.AppDatabase _db;
  final DateTime Function() now;

  /// The server writes every other entry and rejects them from the app.
  @override
  Future<void> log(AuditAction action, String entityId, String studyId) async {
    if (action != AuditAction.consentExported) {
      throw ArgumentError.value(action, 'action', 'only exports are logged');
    }
    await _db
        .into(_db.auditLog)
        .insert(
          db.AuditLogCompanion.insert(
            id: const Uuid().v4(),
            studyId: studyId,
            action: 'consent_exported',
            entityId: entityId,
            createdAt: Value(now().toUtc().toIso8601String()),
          ),
        );
  }

  @override
  Future<List<AuditEntry>> forStudy(String studyId) async {
    final rows =
        await (_db.select(_db.auditLog)
              ..where((a) => a.studyId.equals(studyId))
              ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
            .get();
    return [
      for (final r in rows)
        AuditEntry.fromJson({
          'id': r.id,
          // Both set by the server; empty until the entry has synced.
          'institution_id': r.institutionId ?? '',
          'actor_id': r.actorId ?? '',
          'study_id': r.studyId,
          'action': r.action,
          'entity_id': r.entityId,
          'created_at': r.createdAt ?? now().toUtc().toIso8601String(),
          'received_at': r.receivedAt,
        }),
    ];
  }
}
