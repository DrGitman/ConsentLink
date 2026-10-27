import 'dart:typed_data';

import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/ai_providers.dart';
import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/domain/drafting_event.dart';
import 'package:consentlink/ai/domain/rule_report.dart';
import 'package:consentlink/ai/drafting/consent_drafting_service.dart';
import 'package:consentlink/ai/drafting/fake_consent_drafting_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DraftingRequest _request({
  List<int> bytes = const [1],
  String name = 'proposal.pdf',
  StudyProfile profile = StudyProfile.standard,
}) => DraftingRequest(
  fileBytes: Uint8List.fromList(bytes),
  fileName: name,
  profile: profile,
);

Future<DraftingCompleted> _complete(StudyProfile profile) async {
  const service = FakeConsentDraftingService(stepDelay: Duration.zero);
  final events = await service.draft(_request(profile: profile)).toList();
  return events.last as DraftingCompleted;
}

List<ConsentElement> _notOk(RuleReport report) => [
  for (final item in report.items)
    if (item.status != RuleStatus.ok) item.element,
];

void main() {
  group('DraftingRequest', () {
    test('rejects an empty file', () {
      expect(
        () => _request(bytes: []),
        throwsA(isA<InvalidDraftingRequestException>()),
      );
    });

    test('rejects a blank file name', () {
      expect(
        () => _request(name: '  '),
        throwsA(isA<InvalidDraftingRequestException>()),
      );
    });
  });

  group('FakeConsentDraftingService', () {
    test('starts and completes every step in order, then completes', () async {
      const service = FakeConsentDraftingService(stepDelay: Duration.zero);

      final events = await service.draft(_request()).toList();

      expect(events.take(events.length - 1), [
        for (final step in DraftingStep.values) ...[
          DraftingStepStarted(step),
          DraftingStepCompleted(step),
        ],
      ]);
      expect(events.last, isA<DraftingCompleted>());
    });

    test('standard study: nine sections, contacts_ethics missing', () async {
      final completed = await _complete(StudyProfile.standard);

      expect(completed.draft.sections, hasLength(9));
      expect(completed.draft.missing, [ConsentElement.contactsEthics]);
      expect(completed.report.required, 10);
      expect(completed.report.found, 9);
      expect(_notOk(completed.report), [ConsentElement.contactsEthics]);
    });

    test('study with minors also reports the four minors elements', () async {
      final completed = await _complete(StudyProfile.minors);

      const expectedMissing = [
        ConsentElement.contactsEthics,
        ConsentElement.guardianPermission,
        ConsentElement.childAssent,
        ConsentElement.childDissentRespected,
        ConsentElement.safeguardingContact,
      ];
      expect(completed.draft.missing, expectedMissing);
      expect(completed.report.required, 14);
      expect(_notOk(completed.report), expectedMissing);
    });

    test('missing items carry a fix hint', () async {
      final completed = await _complete(StudyProfile.minors);

      final notOk = completed.report.items.where(
        (item) => item.status != RuleStatus.ok,
      );
      expect(notOk.every((item) => item.fixHint != null), isTrue);
    });
  });

  test('provider returns the fake drafting service', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(consentDraftingServiceProvider),
      isA<FakeConsentDraftingService>(),
    );
  });
}
