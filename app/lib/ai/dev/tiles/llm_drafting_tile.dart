import 'dart:async';
import 'dart:developer' show log;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_exceptions.dart';
import '../../ai_providers.dart';
import '../../domain/consent_element.dart';
import '../../domain/drafting_event.dart';
import '../../drafting/consent_drafting_service.dart';
import '../../drafting/llm_consent_drafting_service.dart';
import '../../llm/llm_model_config.dart';
import 'fake_drafting_tile.dart' show describeDraftingEvent;

const llmDraftingTitle = 'LLM drafting (Gemma 4 E2B)';
const llmDraftingRunLabel = 'Pick a PDF and draft';
const llmDraftingMinorsLabel = 'Study involves minors';
const _loadingText = 'Loading the model…';
const _logName = 'ai.drafting';

/// Drafts a real PDF on the phone. Per-attempt details are in the
/// `ai.drafting` log (DevTools). Never shows form text, only its shape.
class LlmDraftingTile extends ConsumerStatefulWidget {
  const LlmDraftingTile({super.key});

  @override
  ConsumerState<LlmDraftingTile> createState() => _LlmDraftingTileState();
}

class _LlmDraftingTileState extends ConsumerState<LlmDraftingTile> {
  final _lines = <String>[];
  final _stopwatch = Stopwatch();
  StreamSubscription<DraftingEvent>? _subscription;
  bool _involvesMinors = false;
  bool _running = false;

  Future<void> _run() async {
    final file = await _pickPdf();
    if (file == null) return;
    setState(() {
      _running = true;
      _lines
        ..clear()
        ..add(_loadingText);
    });
    try {
      final runtime = ref.read(llmRuntimeProvider);
      _stopwatch.reset();
      _stopwatch.start();
      await runtime.load(
        LlmModelConfig(
          modelPath: await deviceModelPath(),
          contextSize: largeContextSize,
        ),
      );
      _add('Model loaded');
      final request = DraftingRequest(
        fileBytes: file.bytes!,
        fileName: file.name,
        profile: StudyProfile.fromInvolvesMinors(_involvesMinors),
      );
      _subscription = LlmConsentDraftingService(
        extractor: ref.read(proposalTextExtractorProvider),
        runtime: runtime,
      ).draft(request).listen(_onEvent, onError: _onError, onDone: _onDone);
    } on Object catch (error, stackTrace) {
      // Any failure must free the tile; an unexpected one is logged in full.
      _onError(error, stackTrace);
      _onDone();
    }
  }

  Future<PlatformFile?> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      final file = result?.files.singleOrNull;
      return file?.bytes == null ? null : file;
    } on PlatformException catch (error) {
      _add('✗ File picker: ${error.code}');
      return null;
    }
  }

  void _onEvent(DraftingEvent event) => _add(switch (event) {
    DraftingCompleted(:final draft, :final report, :final failed) => [
      for (final section in draft.sections)
        '${section.element.jsonKey}: ${section.confidence.name}, '
            'pages ${section.sourcePages}',
      'missing [${draft.missing.map((e) => e.jsonKey).join(', ')}]',
      'failed [${failed.map((e) => e.jsonKey).join(', ')}]',
      'reading grade ${draft.readingGrade?.toStringAsFixed(1) ?? '—'}',
      'rules ${report.found}/${report.required} ok',
    ].join('\n'),
    _ => describeDraftingEvent(event),
  });

  void _onError(Object error, [StackTrace? stackTrace]) {
    if (error is ConsentAiException) {
      _add('✗ $error');
      return;
    }
    log(
      'Unexpected failure',
      name: _logName,
      error: error,
      stackTrace: stackTrace,
    );
    _add('✗ unexpected: ${error.runtimeType}');
  }

  void _onDone() {
    if (!mounted) return;
    setState(() {
      _running = false;
      _subscription = null;
    });
  }

  void _add(String line) {
    if (!mounted) return;
    setState(() => _lines.add('${_stopwatch.elapsed.inSeconds} s  $line'));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            llmDraftingTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            title: const Text(llmDraftingMinorsLabel),
            value: _involvesMinors,
            onChanged: _running
                ? null
                : (value) => setState(() => _involvesMinors = value),
          ),
          FilledButton(
            onPressed: _running ? null : _run,
            child: const Text(llmDraftingRunLabel),
          ),
          for (final line in _lines) Text(line),
        ],
      ),
    ),
  );
}
