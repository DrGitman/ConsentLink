import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_exceptions.dart';
import '../../ai_providers.dart';
import '../../llm/llm_benchmark.dart';
import '../../llm/llm_model_config.dart';

const llmBenchmarkTitle = 'LLM benchmark (Gemma 4 E2B)';
const llmBenchmarkRunLabel = 'Load and generate';
const _runningText = 'Loading the model, then generating…';

/// Measures load time, speed and memory of the on-device model.
class LlmBenchmarkTile extends ConsumerStatefulWidget {
  const LlmBenchmarkTile({super.key});

  @override
  ConsumerState<LlmBenchmarkTile> createState() => _LlmBenchmarkTileState();
}

class _LlmBenchmarkTileState extends ConsumerState<LlmBenchmarkTile> {
  int _contextSize = smallContextSize;
  bool _running = false;
  String? _status;
  String? _sample;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _status = _runningText;
      _sample = null;
    });
    try {
      final result = await runBenchmark(
        ref.read(llmRuntimeProvider),
        LlmModelConfig(
          modelPath: await deviceModelPath(),
          contextSize: _contextSize,
        ),
        currentRss: () => ProcessInfo.currentRss,
        maxRss: () => ProcessInfo.maxRss,
      );
      debugPrint('LLM benchmark (ctx $_contextSize): ${result.summary}');
      _show(result.summary, result.sampleText);
    } on ConsentAiException catch (error) {
      _show('✗ ${error.message}', null);
    }
  }

  void _show(String status, String? sample) {
    if (!mounted) return;
    setState(() {
      _running = false;
      _status = status;
      _sample = sample;
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            llmBenchmarkTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: smallContextSize,
                label: Text('ctx $smallContextSize'),
              ),
              ButtonSegment(
                value: largeContextSize,
                label: Text('ctx $largeContextSize'),
              ),
            ],
            selected: {_contextSize},
            onSelectionChanged: _running
                ? null
                : (sizes) => setState(() => _contextSize = sizes.single),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _running ? null : _run,
            child: const Text(llmBenchmarkRunLabel),
          ),
          if (_status case final status?) Text(status),
          if (_sample case final sample?) Text(sample),
        ],
      ),
    ),
  );
}
