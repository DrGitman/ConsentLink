import 'dart:io';
import 'dart:typed_data';

import 'package:consentlink/contracts/models.dart';
import 'package:consentlink/data/export/consent_export_service.dart';
import 'package:consentlink/data/local/app_database.dart' show AppDatabase;
import 'package:consentlink/data/repositories/drift_consent_repository.dart';
import 'package:consentlink/data/repositories/drift_study_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ByteData> _font(String name) async =>
    ByteData.sublistView(await File('assets/fonts/$name').readAsBytes());

void main() {
  late AppDatabase db;
  late DriftAuditRepository audit;
  late ConsentExportService export;
  late Consent consent;
  late Study study;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final studies = DriftStudyRepository(db);
    final consents = DriftConsentRepository(db);
    audit = DriftAuditRepository(db);
    export = ConsentExportService(
      studies: studies,
      consents: consents,
      audit: audit,
      fonts: () async =>
          (await _font('Inter-Regular.ttf'), await _font('Inter-SemiBold.ttf')),
    );
    study = await studies.createStudy(
      const StudyDraft(title: 'Water use, "Nyae Nyae"', involvesMinors: false),
    );
    await studies.saveSection(
      ConsentSection(
        id: 's1',
        studyId: study.id,
        order: 0,
        language: 'ktz',
        text: 'Juǀ\'hoansi: ǀʼa ǁhai ǂoa ǃxoan',
        status: SectionStatus.draft,
      ),
    );
    await studies.approveSection('s1');
    study = await studies.publishForm(study.id);
    final p = await DriftParticipantRepository(db).create(
      ParticipantDraft(studyId: study.id, language: 'ktz', isMinor: false),
    );
    consent = await consents.saveConsent(
      ConsentDraft(
        studyId: study.id,
        participantId: p.id,
        language: 'ktz',
        decision: ConsentDecision.yes,
        method: ConsentMethod.thumbprint,
        witnessName: 'Kxao',
        formVersion: study.formVersion,
        formHash: study.formHash!,
      ),
    );
  });
  tearDown(() => db.close());

  test('a consent exports as a PDF and the export is logged', () async {
    final pdf = await export.consentPdf(consent.id);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    final trail = await audit.forStudy(study.id);
    expect(trail.single.action, AuditAction.consentExported);
    expect(trail.single.entityId, consent.id);
    final sample = Platform.environment['EXPORT_SAMPLE'];
    if (sample != null) File(sample).writeAsBytesSync(pdf);
  });

  test('an unknown consent is refused and nothing is logged', () async {
    await expectLater(export.consentPdf('nope'), throwsStateError);
    expect(await audit.forStudy(study.id), isEmpty);
  });

  test('the study CSV lists its consents and is logged', () async {
    final csv = await export.analyticsCsv(study.id);
    final lines = csv.trim().split('\r\n');
    expect(lines.first, startsWith('consent_id,participant_id,language'));
    expect(lines, hasLength(2));
    expect(lines[1], contains(',ktz,yes,thumbprint,'));
    expect(lines[1], endsWith(study.formHash!));
    expect(
      (await audit.forStudy(study.id)).single.action,
      AuditAction.consentExported,
    );
  });
}
