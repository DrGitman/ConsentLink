import 'package:flutter_tts/flutter_tts.dart';

import '../ai_exceptions.dart';
import 'tts_engine.dart';

// flutter_tts replies 1 when a call worked.
const _success = 1;
const _notInstalledFeature = 'notInstalled';
const _localOnly = '0';

/// [TtsEngine] on the platform engine, through flutter_tts.
final class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<List<String>> languages() async =>
      List<String>.from(await _tts.getLanguages as List? ?? const []);

  @override
  Future<List<TtsVoice>> localVoices() async {
    final voices = await _tts.getVoices as List? ?? const [];
    return [
      for (final Map<Object?, Object?> voice in voices.cast())
        if (voice['network_required'] == _localOnly &&
            !'${voice['features']}'.contains(_notInstalledFeature))
          TtsVoice(name: '${voice['name']}', locale: '${voice['locale']}'),
    ];
  }

  @override
  Future<void> speak(TtsVoice voice, String text) async {
    await _tts.awaitSpeakCompletion(true);
    final voiceSet = await _tts.setVoice({
      'name': voice.name,
      'locale': voice.locale,
    });
    if (voiceSet != _success) {
      throw ReadAloudException(
        'The voice for ${voice.locale} is not on the device.',
      );
    }
    if (await _tts.speak(text) != _success) {
      throw ReadAloudException('The device could not read ${voice.locale}.');
    }
  }

  @override
  Future<void> stop() => _tts.stop();
}
