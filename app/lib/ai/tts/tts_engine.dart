/// A voice installed on the device that works without the network.
final class TtsVoice {
  const TtsVoice({required this.name, required this.locale});

  final String name;

  /// BCP 47 tag from the engine, such as `en-ZA`.
  final String locale;

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);
}

/// The device text-to-speech engine.
abstract interface class TtsEngine {
  /// Locales the engine knows, installed or not.
  Future<List<String>> languages();

  /// Voices that are installed and never need the network (decision D6.3).
  Future<List<TtsVoice>> localVoices();

  /// Reads [text] with [voice] and completes when it has been spoken.
  Future<void> speak(TtsVoice voice, String text);

  Future<void> stop();
}
