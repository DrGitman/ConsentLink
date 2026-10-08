import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/theme_provider.dart';
import 'features/institution/institution.dart';
import 'features/institution/institution_preferences.dart';
import 'features/preferences/accessibility_preferences.dart';
import 'features/preferences/preference_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SharedPreferencesAsync();
  String? savedValue;

  try {
    savedValue = await storage.getString(PreferencePersistence.storageKey);
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
      ],
      child: const ConsentLinkApp(),
    ),
  );
}
