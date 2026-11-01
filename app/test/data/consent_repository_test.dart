import 'package:consentlink/contracts/models.dart';
import 'package:consentlink/data/local/app_database.dart' show AppDatabase;
import 'package:consentlink/data/repositories/drift_consent_repository.dart';
import 'package:consentlink/data/repositories/drift_study_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftStudyRepository studies;
  late DriftConsentRepository consents;
  late DriftParticipantRepository participants;
  late DriftAuditRepository audit;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    studies = DriftStudyRepository(db);
    consents = DriftConsentRepository(db);
    participants = DriftParticipantRepository(db);
    audit = DriftAuditRepository(db);
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
  Future<Study> published({bool minors = false}) async {
    final study = await studies.createStudy(
      StudyDraft(title: 'Water use', involvesMinors: minors),
    );
    await studies.saveSection(section(study.id, 's1', 'Purpose', 0));
    await studies.saveSection(section(study.id, 's2', 'Risks', 1));
    await studies.approveSection('s1');
    await studies.approveSection('s2');
    return studies.publishForm(study.id);
  }

  Future<Participant> person(Study study, {bool minor = false}) =>
      participants.create(
        ParticipantDraft(studyId: study.id, language: 'en', isMinor: minor),
      );

  ConsentDraft draft(
    Study study,
    String participantId, {
    ConsentDecision decision = ConsentDecision.yes,
    bool? guardian,
    bool? assent,
    String? hash,
  }) => ConsentDraft(
    studyId: study.id,
    participantId: participantId,
    language: 'en',
    decision: decision,
    method: ConsentMethod.signature,
    guardianConsent: guardian,
    childAssent: assent,
    formVersion: study.formVersion,
    formHash: hash ?? study.formHash!,
  );

  test('a consent must match the published form', () async {
    final study = await published();
    final p = await person(study);
    await expectLater(
      consents.saveConsent(draft(study, p.id, hash: 'wrong')),
      throwsStateError,
    );
    final saved = await consents.saveConsent(draft(study, p.id));
    expect(saved.formHash, study.formHash);
    expect(await consents.listByStudy(study.id), hasLength(1));
  });

  test(
    "a minor's Yes needs guardian consent and assent; No always counts",
    () async {
      final study = await published(minors: true);
      final child = await person(study, minor: true);
      await expectLater(
        consents.saveConsent(
          draft(study, child.id, guardian: true, assent: false),
        ),
        throwsStateError,
      );
      await expectLater(
        consents.saveConsent(draft(study, child.id)),
        throwsStateError,
        reason: 'both must be recorded',
      );
      final no = await consents.saveConsent(
        draft(
          study,
          child.id,
          decision: ConsentDecision.no,
          guardian: true,
          assent: false,
        ),
      );
      expect(no.decision, ConsentDecision.no);
    },
  );

  test('a withdrawal is kept and can never be undone', () async {
    final study = await published();
    final p = await person(study);
    final consent = await consents.saveConsent(draft(study, p.id));
    await consents.withdraw(consent.id, 'Changed my mind');
    final withdrawn = (await consents.getConsent(consent.id))!;
    expect(withdrawn.withdrawalReason, 'Changed my mind');
    expect(withdrawn.withdrawnAt, isNotNull);
    await expectLater(consents.withdraw(consent.id, 'again'), throwsStateError);
  });

  test('the app only logs exports; entries come back for the study', () async {
    await audit.log(AuditAction.consentExported, 'k1', 'study1');
    await expectLater(
      audit.log(AuditAction.consentSigned, 'k1', 'study1'),
      throwsArgumentError,
    );
    final entries = await audit.forStudy('study1');
    expect(entries.single.action, AuditAction.consentExported);
    expect(await consents.watchSyncStatus().first, SyncStatus.offline);
  });
}
