import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech to text for participant answers (Figma 06.3). Uses the phone's
/// own recogniser through speech_to_text, the same as the dictation sheet.
/// Tests replace it through [voiceInputProvider].
abstract class VoiceInput {
  /// Starts listening. Returns false when voice input isn't available
  /// (no recogniser, permission refused, or an error).
  Future<bool> start({
    required void Function(String text) onText,
    required void Function(double level) onLevel,
    required void Function() onStopped,
  });

  Future<void> stop();
}

final voiceInputProvider = Provider<VoiceInput>((ref) {
  final input = SpeechVoiceInput();
  ref.onDispose(input.stop);
  return input;
});

class SpeechVoiceInput implements VoiceInput {
  final _speech = SpeechToText();
  bool? _available;
  void Function()? _onStopped;

  @override
  Future<bool> start({
    required void Function(String text) onText,
    required void Function(double level) onLevel,
    required void Function() onStopped,
  }) async {
    try {
      _onStopped = onStopped;
      _available ??= await _speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            _onStopped?.call();
          }
        },
        onError: (_) => _onStopped?.call(),
      );
      if (_available != true) return false;
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
        ),
        onResult: (result) => onText(result.recognizedWords),
        // Android reports roughly −2 … 10 dB.
        onSoundLevelChange: (db) => onLevel(((db + 2) / 12).clamp(0.0, 1.0)),
      );
      return true;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  @override
  Future<void> stop() async {
    _onStopped = null;
    try {
      await _speech.stop();
    } catch (_) {}
  }
}
