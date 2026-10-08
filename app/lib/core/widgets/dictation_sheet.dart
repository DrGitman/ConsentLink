import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

final _speech = SpeechToText();
void Function(String)? _statusListener;
void Function(SpeechRecognitionError)? _errorListener;
bool _dictationOpen = false;

Future<String?> showDictationSheet(
  BuildContext context, {
  required String fieldLabel,
}) async {
  if (_dictationOpen) return null;
  _dictationOpen = true;

  try {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DictationSheet(fieldLabel: fieldLabel),
    );
  } finally {
    _statusListener = null;
    _errorListener = null;
    try {
      await _speech.cancel();
    } finally {
      _dictationOpen = false;
    }
  }
}

class _DictationSheet extends StatefulWidget {
  const _DictationSheet({required this.fieldLabel});

  final String fieldLabel;

  @override
  State<_DictationSheet> createState() => _DictationSheetState();
}

class _DictationSheetState extends State<_DictationSheet>
    with WidgetsBindingObserver {
  final _text = TextEditingController();

  bool _busy = false;
  bool _listening = false;
  bool _acceptResults = false;
  int _generation = 0;
  String? _error;
  bool _ready = false;
  List<LocaleName> _languages = [];
  String? _localeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _statusListener = (status) {
      if (!mounted) return;
      setState(() {
        _listening = status == 'listening';
      });
    };

    _errorListener = (error) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _acceptResults = false;
        _error = switch (error.errorMsg) {
          'error_permission' || 'error_insufficient_permissions' =>
            'Microphone access is required. Check ConsentLink permissions '
                'in your phone settings.',
          'error_no_match' || 'error_speech_timeout' =>
            'No speech was recognised. Tap Start speaking and try again.',
          'error_network' || 'error_network_timeout' =>
            'Speech recognition could not connect. Check your connection.',
          'error_recognizer_busy' || 'error_busy' =>
            'The phone’s speech service is busy. Wait a moment and retry.',
          _ => 'Speech recognition stopped. You can retry or type instead.',
        };
      });
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _generation++;
      _acceptResults = false;
      unawaited(_speech.cancel());
      if (mounted) {
        setState(() {
          _listening = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _prepare() async {
    if (_busy) return;

    final generation = ++_generation;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final available = await _speech.initialize(
        onStatus: (status) => _statusListener?.call(status),
        onError: (error) => _errorListener?.call(error),
        options: [SpeechToText.androidNoBluetooth],
      );

      if (!mounted || generation != _generation) return;

      if (!available) {
        setState(() {
          _error =
              'Speech recognition is unavailable. Check microphone '
              'permission and your phone’s speech service.';
        });
        return;
      }

      final availableLanguages = await _speech.locales();
      final systemLanguage = await _speech.systemLocale();

      if (!mounted || generation != _generation) return;

      final unique = <String, LocaleName>{
        for (final language in availableLanguages) language.localeId: language,
      };

      final languages = unique.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final systemId = systemLanguage?.localeId;

      setState(() {
        _languages = languages;
        _localeId = unique.containsKey(systemId)
            ? systemId
            : languages.isEmpty
            ? null
            : languages.first.localeId;
        _ready = true;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = 'Could not load speech languages. Please retry.';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _start() async {
    if (_busy || _listening) return;

    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final available = await _speech.initialize(
        onStatus: (status) => _statusListener?.call(status),
        onError: (error) => _errorListener?.call(error),
        options: [SpeechToText.androidNoBluetooth],
      );

      if (!mounted || generation != _generation) return;

      if (!available) {
        setState(() {
          _error =
              'Speech recognition is unavailable. Check microphone '
              'permission and whether your phone has a speech service.';
        });
        return;
      }

      await _speech.cancel();
      if (!mounted || generation != _generation) return;

      final previous = _text.text.trimRight();
      final prefix = previous.isEmpty ? '' : '$previous ';

      _acceptResults = true;

      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
        ),
        onResult: (result) {
          if (!mounted || generation != _generation || !_acceptResults) {
            return;
          }

          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;

          final value = '$prefix$words';
          _text.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
          setState(() {});
        },
      );

      if (!mounted || generation != _generation) {
        await _speech.cancel();
        return;
      }

      setState(() {
        _listening = _speech.isListening;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _acceptResults = false;
          _listening = false;
          _error =
              'Could not start speech recognition. Please retry '
              'or type instead.';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _speech.stop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Speech recognition stopped. Review the text below.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _listening = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _acceptResults = false;
    _statusListener = null;
    _errorListener = null;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_speech.cancel());
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.fieldLabel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel dictation',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose the language you will speak. Your phone’s speech '
              'service may process audio online. Choosing a language can '
              'help recognition when the phone’s default is wrong, but it '
              'does not isolate speech or remove background noise. Review '
              'the result before inserting.',
            ),
            if (_ready) ...[
              const SizedBox(height: 16),
              if (_languages.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _localeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Spoken language',
                  ),
                  items: [
                    for (final language in _languages)
                      DropdownMenuItem(
                        value: language.localeId,
                        child: Text(
                          language.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy || _listening
                      ? null
                      : (value) {
                          _generation++;
                          _acceptResults = false;
                          setState(() {
                            _localeId = value;
                            _error = null;
                          });
                        },
                )
              else
                const Text(
                  'Your speech service did not list its languages. '
                  'Recognition will use the phone’s default.',
                ),
            ],
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(
                _listening
                    ? 'Listening… Tap Stop when finished.'
                    : !_ready
                    ? 'Set up voice input to choose a spoken language.'
                    : 'Check the spoken language, then tap Start speaking.',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              readOnly: _listening || _busy,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Recognised text',
                hintText: 'Your words will appear here',
              ),
              onChanged: (_) {
                _acceptResults = false;
                setState(() {});
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: TextStyle(color: colors.error)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : !_ready
                  ? _prepare
                  : _listening
                  ? _stop
                  : _start,
              icon: Icon(_listening ? Icons.stop : Icons.mic_none),
              label: Text(
                _busy
                    ? 'Please wait…'
                    : !_ready
                    ? 'Set up voice input'
                    : _listening
                    ? 'Stop'
                    : 'Start speaking',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy || _listening || _text.text.trim().isEmpty
                  ? null
                  : () {
                      _acceptResults = false;
                      Navigator.pop(context, _text.text.trim());
                    },
              child: const Text('Use this text'),
            ),
          ],
        ),
      ),
    );
  }
}
