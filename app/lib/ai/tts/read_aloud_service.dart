import 'package:consentlink/contracts/languages.dart';

import '../ai_exceptions.dart';
import 'audio_source.dart';
import 'tts_engine.dart';

/// Device locales to try for each app language, best first. Other languages
/// try their own code.
const ttsLocalesByLanguage = {
  'en': ['en-ZA', 'en-GB', 'en-US', 'en'],
  'af': ['af-ZA', 'af'],
  'de': ['de-DE', 'de'],
};

/// Chooses how a consent text is read aloud, and reads it with the device.
final class ReadAloudService {
  const ReadAloudService(this._engine);

  final TtsEngine _engine;

  /// A recording first, else a local device voice, else [NoAudio].
  ///
  /// Throws an [UnsupportedLanguageException] for a code that is not in
  /// `contracts/languages.dart`.
  Future<AudioSource> resolve(
    String languageCode, {
    String? recordingPath,
  }) async {
    if (languageByCode(languageCode) == null) {
      throw UnsupportedLanguageException('Unknown language "$languageCode".');
    }
    if (recordingPath != null) {
      if (recordingPath.trim().isEmpty) {
        throw ArgumentError.value(recordingPath, 'recordingPath', 'Is blank');
      }
      return RecordedAudio(recordingPath);
    }
    final locales = _localesFor(languageCode);
    final voice = _voiceFor(locales, await _engine.localVoices());
    if (voice != null) return DeviceTts(voice);
    final known = (await _engine.languages()).any(
      (locale) => locales.any((candidate) => _matches(candidate, locale)),
    );
    return NoAudio(
      known
          ? NoAudioReason.voiceNotInstalled
          : NoAudioReason.languageNotSupported,
    );
  }

  /// App language codes that this device can read aloud without a recording.
  Future<List<String>> availableLanguages() async {
    final voices = await _engine.localVoices();
    return [
      for (final language in consentLanguages)
        if (_voiceFor(_localesFor(language.code), voices) != null)
          language.code,
    ];
  }

  /// Reads [text] with [source]'s voice; throws [ReadAloudException] on failure.
  Future<void> speak(DeviceTts source, String text) {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'Is blank');
    }
    return _engine.speak(source.voice, text);
  }

  Future<void> stop() => _engine.stop();

  static List<String> _localesFor(String languageCode) =>
      ttsLocalesByLanguage[languageCode] ?? [languageCode];

  // Candidates are tried in order, so en-ZA wins over any other English voice.
  static TtsVoice? _voiceFor(List<String> locales, List<TtsVoice> voices) =>
      locales
          .expand((locale) => voices.where((v) => _matches(locale, v.locale)))
          .firstOrNull;

  // A bare code such as `en` matches any region of that language.
  static bool _matches(String candidate, String deviceLocale) {
    final wanted = candidate.toLowerCase();
    final actual = deviceLocale.toLowerCase().replaceAll('_', '-');
    return actual == wanted ||
        (!wanted.contains('-') && actual.split('-').first == wanted);
  }
}
