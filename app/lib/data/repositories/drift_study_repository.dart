// data/repositories/drift_study_repository.dart
// StudyRepository on the local database. The same rules as the server, so the
// phone refuses what the server would refuse: editing approved text drops
// the approval, and a form is published only when every section is approved.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../contracts/form_hash.dart';
import '../../contracts/models.dart';
import '../../contracts/study_repository.dart';
import '../local/app_database.dart' as db;

class DriftStudyRepository implements StudyRepository {
  DriftStudyRepository(this._db, {this.now = DateTime.now});
  final db.AppDatabase _db;
  final DateTime Function() now;

  String _time() => now().toUtc().toIso8601String();

  @override
  Future<Study> createStudy(StudyDraft draft) async {
    final id = const Uuid().v4();
    await _db
        .into(_db.studies)
        .insert(
          db.StudiesCompanion.insert(
            id: id,
            title: draft.title,
            involvesMinors: draft.involvesMinors,
            status: 'draft',
            createdAt: Value(_time()),
          ),
        );
    return (await _study(id))!;
  }

  @override
  Future<List<Study>> listStudies() async {
    final rows = await (_db.select(
      _db.studies,
    )..orderBy([(s) => OrderingTerm.desc(s.createdAt)])).get();
    return [for (final row in rows) await _toStudy(row)];
  }

  @override
  Future<List<ConsentSection>> getSections(String studyId) async {
    final rows =
        await (_db.select(_db.consentSections)
              ..where((s) => s.studyId.equals(studyId))
              ..orderBy([
                (s) => OrderingTerm.asc(s.language),
                (s) => OrderingTerm.asc(s.order),
              ]))
            .get();
    return rows.map(_toSection).toList();
  }

  @override
  Future<void> saveSection(ConsentSection section) async {
    final old = await _sectionRow(section.id);
    var status = section.status;
    if (old?.status == 'approved' && old!.body != section.text) {
      status = SectionStatus.edited;
    }
    final approved = status == SectionStatus.approved;
    final json = section.toJson();
    await _db
        .into(_db.consentSections)
        .insertOnConflictUpdate(
          db.ConsentSectionsCompanion.insert(
            id: section.id,
            studyId: section.studyId,
            order: section.order,
            language: section.language,
            body: section.text,
            sourcePage: Value(section.sourcePage),
            sourceQuote: Value(section.sourceQuote),
            changes: Value(jsonEncode(section.changes)),
            confidence: Value(json['confidence'] as String?),
            requiredElement: Value(section.requiredElement),
            status: status.name,
            approvedBy: Value(approved ? section.approvedBy : null),
            approvedAt: Value(approved ? json['approved_at'] as String? : null),
            createdAt: Value(old?.createdAt ?? _time()),
          ),
        );
  }

  @override
  Future<void> approveSection(String sectionId) async {
    final changed =
        await (_db.update(
          _db.consentSections,
        )..where((s) => s.id.equals(sectionId))).write(
          db.ConsentSectionsCompanion(
            status: const Value('approved'),
            approvedAt: Value(_time()),
          ),
        );
    if (changed == 0) throw StateError('No section $sectionId');
  }

  @override
  Future<Study> publishForm(String studyId) async {
    final sections = await getSections(studyId);
    if (sections.isEmpty ||
        sections.any((s) => s.status != SectionStatus.approved)) {
      throw StateError('Every section must be approved before publishing.');
    }
    final study = (await _study(studyId))!;
    await _db
        .into(_db.formVersions)
        .insert(
          db.FormVersionsCompanion.insert(
            id: const Uuid().v4(),
            studyId: studyId,
            version: study.formVersion + 1,
            formHash: computeFormHash(sections),
            sections: jsonEncode([for (final s in sections) s.toJson()]),
            publishedAt: Value(_time()),
          ),
        );
    // The server updates studies.form_version itself; locally it is read
    // from the newest form version, so nothing here is uploaded twice.
    return (await _study(studyId))!;
  }

  @override
  Future<List<ConsentSection>> getPublishedSections(String studyId) async {
    final latest = await _latestForm(studyId);
    if (latest == null) return const [];
    return [
      for (final s in jsonDecode(latest.sections) as List)
        ConsentSection.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<db.FormVersion?> _latestForm(String studyId) =>
      (_db.select(_db.formVersions)
            ..where((f) => f.studyId.equals(studyId))
            ..orderBy([(f) => OrderingTerm.desc(f.version)])
            ..limit(1))
          .getSingleOrNull();

  Future<db.ConsentSection?> _sectionRow(String id) => (_db.select(
    _db.consentSections,
  )..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<Study?> _study(String id) async {
    final row = await (_db.select(
      _db.studies,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toStudy(row);
  }

  Future<Study> _toStudy(db.Study row) async {
    final form = await _latestForm(row.id);
    return Study(
      id: row.id,
      // Set by the server from the signed-in researcher; empty until synced.
      institutionId: row.institutionId ?? '',
      researcherId: row.researcherId ?? '',
      title: row.title,
      involvesMinors: row.involvesMinors,
      status: StudyStatus.values.byName(row.status),
      formVersion: form?.version ?? 0,
      formHash: form?.formHash,
    );
  }

  ConsentSection _toSection(db.ConsentSection row) => ConsentSection.fromJson({
    'id': row.id,
    'study_id': row.studyId,
    'order': row.order,
    'language': row.language,
    'text': row.body,
    'source_page': row.sourcePage,
    'source_quote': row.sourceQuote,
    'changes': jsonDecode(row.changes),
    'confidence': row.confidence,
    'required_element': row.requiredElement,
    'status': row.status,
    'approved_by': row.approvedBy,
    'approved_at': row.approvedAt,
  });
}
