import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_provider.dart';
import '../institution/institution.dart';
import '../institution/institution_preferences.dart';
import 'accessibility_preferences.dart';

class PreferencePersistence extends ProviderObserver {
  PreferencePersistence({required this.write});

  static const storageKey = 'consentlink.preferences.v1';

  final Future<void> Function(String value) write;

  String? _pending;
  Future<void> _writes = Future<void>.value();

  static Map<String, dynamic> decode(String? source) {
    final result = <String, dynamic>{
      'language': 'English',
      'textScale': 1.0,
      'highContrast': false,
      'readAloud': false,
      'voiceAnswers': false,
      'largerTargets': false,
      'institution': null,
      'researchRole': null,
    };

    if (source == null) return result;

    dynamic decoded;

    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return result;
    }

    if (decoded is! Map<String, dynamic>) return result;

    const languages = {
      'English',
      'Afrikaans',
      'Deutsch',
      'Otjiherero',
      'Khoekhoegowab',
      'Rukwangali',
      'Silozi',
      'Oshiwambo',
    };

    if (languages.contains(decoded['language'])) {
      result['language'] = decoded['language'];
    }

    final scale = decoded['textScale'];
    if (scale is num && scale.isFinite) {
      result['textScale'] = scale.toDouble().clamp(1.0, 1.6).toDouble();
    }

    for (final key in [
      'highContrast',
      'readAloud',
      'voiceAnswers',
      'largerTargets',
    ]) {
      if (decoded[key] is bool) {
        result[key] = decoded[key];
      }
    }

    final institutionName = decoded['institution'];
    final roleName = decoded['researchRole'];

    final validInstitution = Institution.values.any(
      (value) => value.name == institutionName,
    );
    final validRole = ResearchRole.values.any(
      (value) => value.name == roleName,
    );

    if (validInstitution && validRole) {
      result['institution'] = institutionName;
      result['researchRole'] = roleName;
    }

    return result;
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    final isPreference =
        provider == selectedAppLanguageProvider ||
        provider == appTextScaleProvider ||
        provider == highContrastProvider ||
        provider == readScreensAloudProvider ||
        provider == voiceAnswersProvider ||
        provider == largerTouchTargetsProvider ||
        provider == selectedInstitutionProvider ||
        provider == selectedResearchRoleProvider;

    if (!isPreference) return;

    _pending = jsonEncode({
      'language': container.read(selectedAppLanguageProvider),
      'textScale': container.read(appTextScaleProvider),
      'highContrast': container.read(highContrastProvider),
      'readAloud': container.read(readScreensAloudProvider),
      'voiceAnswers': container.read(voiceAnswersProvider),
      'largerTargets': container.read(largerTouchTargetsProvider),
      'institution': container.read(selectedInstitutionProvider)?.name,
      'researchRole': container.read(selectedResearchRoleProvider)?.name,
    });

    _writes = _writes.then((_) async {
      final snapshot = _pending;
      _pending = null;

      if (snapshot == null) return;

      try {
        await write(snapshot);
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'ConsentLink preferences',
            context: ErrorDescription('while saving preferences'),
          ),
        );
      }
    });
  }

  Future<void> flush() => _writes;
}
