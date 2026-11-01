import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/tts/audio_source.dart';
import 'package:consentlink/ai/tts/flutter_tts_engine.dart';
import 'package:consentlink/ai/tts/read_aloud_service.dart';
import 'package:consentlink/ai/tts/tts_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/khoekhoegowab_fixture.dart';

const _englishSa = TtsVoice(name: 'en-za-local', locale: 'en-ZA');
const _englishUs = TtsVoice(name: 'en-us-local', locale: 'en-US');
const _german = TtsVoice(name: 'de-local', locale: 'de-DE');

final class _FakeEngine implements TtsEngine {
  _FakeEngine({this.voices = const [], this.knownLocales = const []});

  final List<TtsVoice> voices;
  final List<String> knownLocales;
  final spoken = <(TtsVoice, String)>[];

  @override
  Future<List<String>> languages() async => knownLocales;

  @override
  Future<List<TtsVoice>> localVoices() async => voices;

  @override
  Future<void> speak(TtsVoice voice, String text) async =>
      spoken.add((voice, text));

  @override
  Future<void> stop() async {}
}

Matcher _noAudio(NoAudioReason reason) =>
    isA<NoAudio>().having((source) => source.reason, 'reason', reason);

void main() {
  group('resolve', () {
    test('a human recording always comes first', () async {
      final service = ReadAloudService(_FakeEngine(voices: [_englishSa]));
      final source = await service.resolve('en', recordingPath: 'a/en.m4a');
      expect(source, isA<RecordedAudio>());
    });

    test('prefers the South African English voice', () async {
      final service = ReadAloudService(
        _FakeEngine(voices: [_englishUs, _englishSa]),
      );
      expect(((await service.resolve('en')) as DeviceTts).voice, _englishSa);
      const australian = TtsVoice(name: 'au', locale: 'en-AU');
      final fallback = ReadAloudService(_FakeEngine(voices: [australian]));
      expect(((await fallback.resolve('en')) as DeviceTts).voice, australian);
    });

    test('a known language without a local voice is not installed', () async {
      final service = ReadAloudService(_FakeEngine(knownLocales: ['af-ZA']));
      expect(
        await service.resolve('af'),
        _noAudio(NoAudioReason.voiceNotInstalled),
      );
    });

    test('Khoekhoegowab gives no audio, without an error (task K)', () async {
      final service = ReadAloudService(
        _FakeEngine(voices: [_englishSa], knownLocales: ['en-ZA']),
      );
      expect(
        await service.resolve(khoekhoegowabCode),
        _noAudio(NoAudioReason.languageNotSupported),
      );
    });

    test('rejects an unsupported language or a blank recording path', () {
      final service = ReadAloudService(_FakeEngine());
      expect(
        service.resolve('fr'),
        throwsA(isA<UnsupportedLanguageException>()),
      );
      expect(service.resolve('en', recordingPath: ' '), throwsArgumentError);
    });
  });

  test('lists the app languages the device can read', () async {
    final service = ReadAloudService(
      _FakeEngine(voices: [_englishUs, _german]),
    );
    expect(await service.availableLanguages(), ['en', 'de']);
  });

  test('speak reads the text unchanged, clicks included (task K)', () async {
    final engine = _FakeEngine();
    final service = ReadAloudService(engine);
    await service.speak(const DeviceTts(_englishSa), khoekhoegowabSentence);
    expect(engine.spoken.single, (_englishSa, khoekhoegowabSentence));
    expect(
      () => service.speak(const DeviceTts(_englishSa), '  '),
      throwsArgumentError,
    );
  });

  group('FlutterTtsEngine', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('flutter_tts');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'getVoices' => [
                {'name': 'local', 'locale': 'en-ZA', 'network_required': '0'},
                {'name': 'cloud', 'locale': 'en-US', 'network_required': '1'},
                {
                  'name': 'missing',
                  'locale': 'af-ZA',
                  'network_required': '0',
                  'features': 'notInstalled',
                },
              ],
              'setVoice' || 'speak' => 1,
              _ => null,
            };
          });
    });

    test('keeps only installed voices that need no network', () async {
      expect(await FlutterTtsEngine().localVoices(), [
        const TtsVoice(name: 'local', locale: 'en-ZA'),
      ]);
    });

    test('sets the voice before speaking', () async {
      await FlutterTtsEngine().speak(_englishSa, 'Hello');
      expect(
        calls.map((call) => call.method),
        containsAllInOrder(['setVoice', 'speak']),
      );
    });
  });
}
