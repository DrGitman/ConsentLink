import 'package:consentlink/contracts/form_hash.dart';
import 'package:consentlink/contracts/models.dart';
import 'package:consentlink/data/local/app_database.dart' show AppDatabase;
import 'package:consentlink/data/repositories/drift_study_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftStudyRepository studies;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    studies = DriftStudyRepository(db);
  });
  tearDown(() => db.close());

  ConsentSection section(String studyId, String id, String text, int order) =>
      ConsentSection(
        id: id,
        studyId: studyId,
        order: order,
        language: 'en',
        text: text,
        status: SectionStatus.draft,
      );

  /// A study with two approved sections, published as version 1.
  Future<Study> published() async {
    final study = await studies.createStudy(
      const StudyDraft(title: 'Water use', involvesMinors: false),
    );
    await studies.saveSection(section(study.id, 's1', 'Purpose', 0));
    await studies.saveSection(section(study.id, 's2', 'Risks', 1));
    await studies.approveSection('s1');
    await studies.approveSection('s2');
    return studies.publishForm(study.id);
  }

  test('a new study is a draft with nothing published', () async {
    final study = await studies.createStudy(
      const StudyDraft(title: 'T', involvesMinors: false),
    );
    expect(
      (study.status, study.formVersion, study.formHash),
      (StudyStatus.draft, 0, null),
    );
    expect(await studies.listStudies(), hasLength(1));
  });

  test('editing approved text drops the approval', () async {
    final study = await studies.createStudy(
      const StudyDraft(title: 'T', involvesMinors: false),
    );
    await studies.saveSection(section(study.id, 's1', 'Purpose', 0));
    await studies.approveSection('s1');
    final approved = (await studies.getSections(study.id)).single;
    expect(approved.status, SectionStatus.approved);
    await studies.saveSection(
      section(study.id, 's1', 'New purpose', 0).copyApproved(approved),
    );
    final edited = (await studies.getSections(study.id)).single;
    expect((edited.status, edited.approvedAt), (SectionStatus.edited, null));
  });

  test('publishing needs every section approved', () async {
    final study = await studies.createStudy(
      const StudyDraft(title: 'T', involvesMinors: false),
    );
    await studies.saveSection(section(study.id, 's1', 'Purpose', 0));
    await expectLater(studies.publishForm(study.id), throwsStateError);
  });

  test('two quick publishes get different versions', () async {
    final study = await published();
    await Future.wait([
      studies.publishForm(study.id),
      studies.publishForm(study.id),
    ]);
    final versions = await db.select(db.formVersions).get();
    expect(versions.map((v) => v.version).toSet(), {1, 2, 3});
  });

  test('a published form is frozen with its fingerprint', () async {
    final study = await published();
    final frozen = await studies.getPublishedSections(study.id);
    expect(study.formVersion, 1);
    expect(study.formHash, computeFormHash(frozen));
    await studies.saveSection(section(study.id, 's1', 'Changed later', 0));
    expect(
      (await studies.getPublishedSections(study.id)).first.text,
      'Purpose',
      reason: 'later edits never change what a participant agreed to',
    );
  });
}

extension on ConsentSection {
  /// This section, carrying [approved]'s approval (as a screen saving an
  /// edit to an approved section would).
  ConsentSection copyApproved(ConsentSection approved) => ConsentSection(
    id: id,
    studyId: studyId,
    order: order,
    language: language,
    text: text,
    status: SectionStatus.approved,
    approvedBy: approved.approvedBy,
    approvedAt: approved.approvedAt,
  );
}
