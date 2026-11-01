import 'tts_engine.dart';

/// How a text is read aloud: recording first, then the device, else nothing.
sealed class AudioSource {
  const AudioSource();
}

/// A human recording of the text, which always comes first.
final class RecordedAudio extends AudioSource {
  const RecordedAudio(this.path);

  final String path;
}

/// The device reads the text with a local [voice].
final class DeviceTts extends AudioSource {
  const DeviceTts(this.voice);

  final TtsVoice voice;
}

enum NoAudioReason {
  /// The device has no voice at all for the language.
  languageNotSupported,

  /// The device knows the language, but its voice is not downloaded.
  voiceNotInstalled,
}

/// Nothing can read the text aloud; the screen says so clearly.
final class NoAudio extends AudioSource {
  const NoAudio(this.reason);

  final NoAudioReason reason;
}
