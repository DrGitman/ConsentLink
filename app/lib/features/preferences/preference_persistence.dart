import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_provider.dart';
import '../institution/institution.dart';
import '../institution/institution_preferences.dart';
import '../institution/researcher_details_screen.dart'
    show researcherDraftProvider;
import '../settings/settings_data.dart'
    show profilePhotoProvider, researcherEmailProvider;
import 'accessibility_preferences.dart';

class PreferencePersistence extends ProviderObserver {
  PreferencePersistence({required this.write, this.writeKey});

  static const storageKey = 'consentlink.preferences.v1';
  static const photoKey = 'consentlink.profilePhoto.v1';
  static const researcherKey = 'consentlink.researcher.v1';

  final Future<void> Function(String value) write;

  /// Saves one value under its own key ([photoKey], [researcherKey]);
  /// null removes it.
  final Future<void> Function(String key, String? value)? writeKey;

  /// Reads saved researcher details: six onboarding fields and an email.
  static ({List<String> details, String email}) decodeResearcher(
    String? source,
  ) {
    final empty = (details: List<String>.filled(6, ''), email: '');
    if (source == null) return empty;
    try {
      final map = jsonDecode(source);
      if (map is! Map<String, dynamic>) return empty;
      final list = map['details'];
      final details = [
        for (var i = 0; i < 6; i++)
          list is List && i < list.length && list[i] is String
              ? list[i] as String
              : '',
      ];
      final email = map['email'];
      return (details: details, email: email is String ? email : '');
    } on FormatException {
      return empty;
    }
  }

  /// Reads a saved profile photo; bad data is ignored.
  static Uint8List? decodePhoto(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      return base64Decode(source);
    } on FormatException {
      return null;
    }
  }

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
      'reduceMotion': false,
      'dyslexiaFont': false,
      'keepBright': false,
      'readSpeed': 0.9,
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
      'reduceMotion',
      'dyslexiaFont',
      'keepBright',
    ]) {
      if (decoded[key] is bool) {
        result[key] = decoded[key];
      }
    }

    final speed = decoded['readSpeed'];
    if (speed is num && speed.isFinite) {
      result['readSpeed'] = speed.toDouble().clamp(0.5, 2.0).toDouble();
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
    if (provider == profilePhotoProvider) {
      final bytes = newValue as Uint8List?;
      _queue(
        () => writeKey?.call(
          photoKey,
          bytes == null ? null : base64Encode(bytes),
        ),
      );
      return;
    }
    if (provider == researcherDraftProvider ||
        provider == researcherEmailProvider) {
      final value = jsonEncode({
        'details': container.read(researcherDraftProvider),
        'email': container.read(researcherEmailProvider),
      });
      _queue(() => writeKey?.call(researcherKey, value));
      return;
    }

    final isPreference =
        provider == selectedAppLanguageProvider ||
        provider == appTextScaleProvider ||
        provider == highContrastProvider ||
        provider == readScreensAloudProvider ||
        provider == voiceAnswersProvider ||
        provider == largerTouchTargetsProvider ||
        provider == reduceMotionPreferenceProvider ||
        provider == dyslexiaFontProvider ||
        provider == keepScreenBrightProvider ||
        provider == readAloudSpeedProvider ||
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
      'reduceMotion': container.read(reduceMotionPreferenceProvider),
      'dyslexiaFont': container.read(dyslexiaFontProvider),
      'keepBright': container.read(keepScreenBrightProvider),
      'readSpeed': container.read(readAloudSpeedProvider),
      'institution': container.read(selectedInstitutionProvider)?.name,
      'researchRole': container.read(selectedResearchRoleProvider)?.name,
    });

    _queue(() async {
      final snapshot = _pending;
      _pending = null;
      if (snapshot != null) await write(snapshot);
    });
  }

  void _queue(Future<void>? Function() task) {
    _writes = _writes.then((_) async {
      try {
        await task();
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
