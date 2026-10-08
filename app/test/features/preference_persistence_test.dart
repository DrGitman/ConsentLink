import 'dart:convert';

import 'package:consentlink/core/theme/theme_provider.dart';
import 'package:consentlink/features/institution/institution.dart';
import 'package:consentlink/features/institution/institution_preferences.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:consentlink/features/preferences/preference_persistence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalid stored settings fall back to safe defaults', () {
    final corrupt = PreferencePersistence.decode('not valid JSON');

    expect(corrupt['language'], 'English');
    expect(corrupt['textScale'], 1.0);
    expect(corrupt['highContrast'], false);

    final invalidValues = PreferencePersistence.decode(
      '{"language":"Unknown","textScale":99,"highContrast":"yes"}',
    );

    expect(invalidValues['language'], 'English');
    expect(invalidValues['textScale'], 1.6);
    expect(invalidValues['highContrast'], false);
  });

  test('preference changes save the latest complete settings', () async {
    String? stored;

    final persistence = PreferencePersistence(
      write: (value) async {
        await Future<void>.delayed(Duration.zero);
        stored = value;
      },
    );

    final container = ProviderContainer(observers: [persistence]);
    addTearDown(container.dispose);

    container.read(selectedAppLanguageProvider.notifier).state = 'Oshiwambo';
    container.read(appTextScaleProvider.notifier).state = 1.2;
    container.read(appTextScaleProvider.notifier).state = 1.35;
    container.read(highContrastProvider.notifier).state = true;
    container.read(readScreensAloudProvider.notifier).state = true;
    container.read(voiceAnswersProvider.notifier).state = true;
    container.read(largerTouchTargetsProvider.notifier).state = true;

    await persistence.flush();

    expect(stored, isNotNull);

    final restored = PreferencePersistence.decode(stored);
    expect(jsonDecode(stored!), isA<Map<String, dynamic>>());
    expect(restored['language'], 'Oshiwambo');
    expect(restored['textScale'], 1.35);
    expect(restored['highContrast'], true);
    expect(restored['readAloud'], true);
    expect(restored['voiceAnswers'], true);
    expect(restored['largerTargets'], true);
  });

  test('old preferences still restore without an institution', () {
    final restored = PreferencePersistence.decode(
      '{"language":"Oshiwambo","textScale":1.2}',
    );

    expect(restored['language'], 'Oshiwambo');
    expect(restored['textScale'], 1.2);
    expect(restored['institution'], isNull);
    expect(restored['researchRole'], isNull);
  });

  test('invalid or incomplete institution selections are discarded', () {
    for (final source in [
      '{"institution":"unknown","researchRole":"student"}',
      '{"institution":"nust","researchRole":"unknown"}',
      '{"institution":"nust"}',
      '{"researchRole":"student"}',
    ]) {
      final restored = PreferencePersistence.decode(source);
      expect(restored['institution'], isNull);
      expect(restored['researchRole'], isNull);
    }
  });

  test('institution changes preserve accessibility settings', () async {
    String? stored;

    final persistence = PreferencePersistence(
      write: (value) async {
        stored = value;
      },
    );

    final container = ProviderContainer(observers: [persistence]);
    addTearDown(container.dispose);

    container.read(selectedAppLanguageProvider.notifier).state = 'Oshiwambo';
    container.read(appTextScaleProvider.notifier).state = 1.3;
    container.read(highContrastProvider.notifier).state = true;
    container.read(largerTouchTargetsProvider.notifier).state = true;

    container.read(selectedInstitutionProvider.notifier).state =
        Institution.nust;
    container.read(selectedResearchRoleProvider.notifier).state =
        ResearchRole.student;

    await persistence.flush();

    var restored = PreferencePersistence.decode(stored);
    expect(restored['institution'], 'nust');
    expect(restored['researchRole'], 'student');
    expect(restored['language'], 'Oshiwambo');
    expect(restored['textScale'], 1.3);
    expect(restored['highContrast'], true);
    expect(restored['largerTargets'], true);

    container.read(selectedInstitutionProvider.notifier).state =
        Institution.independent;

    await persistence.flush();

    restored = PreferencePersistence.decode(stored);
    expect(restored['institution'], 'independent');
    expect(restored['researchRole'], 'student');
    expect(restored['language'], 'Oshiwambo');
    expect(restored['textScale'], 1.3);
  });
}
