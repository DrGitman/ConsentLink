import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/theme_provider.dart';
import 'features/institution/institution.dart';
import 'features/institution/institution_preferences.dart';
import 'features/institution/researcher_details_screen.dart';
import 'features/preferences/accessibility_preferences.dart';
import 'features/preferences/preference_persistence.dart';
import 'features/settings/settings_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SharedPreferencesAsync();
  String? savedValue;
  String? savedPhoto;
  String? savedResearcher;

  try {
    savedValue = await storage.getString(PreferencePersistence.storageKey);
    savedPhoto = await storage.getString(PreferencePersistence.photoKey);
    savedResearcher = await storage.getString(
      PreferencePersistence.researcherKey,
    );
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'ConsentLink preferences',
        context: ErrorDescription('while loading preferences'),
      ),
    );
  }

  final saved = PreferencePersistence.decode(savedValue);
  final researcher = PreferencePersistence.decodeResearcher(savedResearcher);
  final savedInstitution = saved['institution'] == null
      ? null
      : Institution.values.byName(saved['institution'] as String);

  final savedRole = saved['researchRole'] == null
      ? null
      : ResearchRole.values.byName(saved['researchRole'] as String);

  final restoredTheme = savedInstitution ?? Institution.independent;
  final persistence = PreferencePersistence(
    write: (value) {
      return storage.setString(PreferencePersistence.storageKey, value);
    },
    writeKey: (key, value) =>
        value == null ? storage.remove(key) : storage.setString(key, value),
  );

  runApp(
    ProviderScope(
      observers: [persistence],
      overrides: [
        selectedInstitutionProvider.overrideWith((ref) => savedInstitution),
        selectedResearchRoleProvider.overrideWith((ref) => savedRole),
        institutionSeedProvider.overrideWith((ref) => restoredTheme.primary),
        institutionAccentProvider.overrideWith((ref) => restoredTheme.accent),
        selectedAppLanguageProvider.overrideWith(
          (ref) => saved['language'] as String,
        ),
        appTextScaleProvider.overrideWith(
          (ref) => saved['textScale'] as double,
        ),
        highContrastProvider.overrideWith(
          (ref) => saved['highContrast'] as bool,
        ),
        readScreensAloudProvider.overrideWith(
          (ref) => saved['readAloud'] as bool,
        ),
        voiceAnswersProvider.overrideWith(
          (ref) => saved['voiceAnswers'] as bool,
        ),
        largerTouchTargetsProvider.overrideWith(
          (ref) => saved['largerTargets'] as bool,
        ),
        reduceMotionPreferenceProvider.overrideWith(
          (ref) => saved['reduceMotion'] as bool,
        ),
        dyslexiaFontProvider.overrideWith(
          (ref) => saved['dyslexiaFont'] as bool,
        ),
        keepScreenBrightProvider.overrideWith(
          (ref) => saved['keepBright'] as bool,
        ),
        readAloudSpeedProvider.overrideWith(
          (ref) => saved['readSpeed'] as double,
        ),
        profilePhotoProvider.overrideWith(
          (ref) => PreferencePersistence.decodePhoto(savedPhoto),
        ),
        researcherDraftProvider.overrideWith((ref) => researcher.details),
        researcherEmailProvider.overrideWith((ref) => researcher.email),
      ],
      child: const ConsentLinkApp(),
    ),
  );
}
