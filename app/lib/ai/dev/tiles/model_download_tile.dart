import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_exceptions.dart';
import '../../ai_providers.dart';
import '../../model/model_download_service.dart';

const modelDownloadTitle = 'Model download';
const modelDownloadRunLabel = 'Download';
const modelDownloadCancelLabel = 'Cancel';
const modelDownloadDeleteLabel = 'Delete model';
const modelPresentText = 'Model on the phone';
const modelAbsentText = 'Model not downloaded';
const _wifiWarning = 'Downloads 3.35 GB: use Wi-Fi.';
const _cancelledText = 'Cancelled; the next download resumes.';
const _bytesPerGigabyte = 1024 * 1024 * 1024;
const _percent = 100;

/// Downloads, checks or deletes the on-device model. Dev only.
class ModelDownloadTile extends ConsumerStatefulWidget {
  const ModelDownloadTile({super.key});

  @override
  ConsumerState<ModelDownloadTile> createState() => _ModelDownloadTileState();
}

class _ModelDownloadTileState extends ConsumerState<ModelDownloadTile> {
  final _stopwatch = Stopwatch();
  StreamSubscription<ModelDownloadProgress>? _subscription;
  String _status = '…';
  bool _present = false;

  bool get _running => _subscription != null;
  ModelDownloadService get _service => ref.read(modelDownloadServiceProvider);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final present = await _checkPresence();
    _show(present ? modelPresentText : modelAbsentText);
  }

  /// Greys out Download when the model is there; keeps the status text.
  Future<bool> _checkPresence() async {
    final present = await _service.isDownloaded();
    if (mounted) setState(() => _present = present);
    return present;
  }

  void _download() {
    _stopwatch
      ..reset()
      ..start();
    setState(() {
      _subscription = _service.download().listen(
        _onProgress,
        onError: _onError,
        onDone: _onDone,
      );
    });
  }

  void _onProgress(ModelDownloadProgress progress) => _show(switch (progress) {
    ModelDownloadProgress(phase: ModelDownloadPhase.downloading) =>
      '${(progress.fraction * _percent).toStringAsFixed(0)} % · '
          '${_gb(progress.receivedBytes)} / ${_gb(progress.totalBytes)} GB',
    ModelDownloadProgress(phase: ModelDownloadPhase.verifying) =>
      'Checking the file…',
    ModelDownloadProgress(phase: ModelDownloadPhase.done) =>
      '✓ $modelPresentText (${_stopwatch.elapsed.inSeconds} s)',
  });

  void _onError(Object error) => _show(
    error is ModelDownloadException
        ? '✗ ${error.failure.name}: ${error.message}'
        : '✗ unexpected: ${error.runtimeType}',
  );

  void _onDone() {
    if (!mounted) return;
    setState(() => _subscription = null);
    _checkPresence();
  }

  Future<void> _cancel() async {
    await _subscription?.cancel();
    _onDone();
    _show(_cancelledText);
  }

  Future<void> _delete() async {
    try {
      await _service.deleteModel();
      await _refresh();
    } on ModelDownloadException catch (error) {
      _onError(error);
    }
  }

  void _show(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  static String _gb(int bytes) =>
      (bytes / _bytesPerGigabyte).toStringAsFixed(2);

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
            modelDownloadTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(_wifiWarning),
          Text(_status),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: _running ? _cancel : (_present ? null : _download),
                child: Text(
                  _running ? modelDownloadCancelLabel : modelDownloadRunLabel,
                ),
              ),
              OutlinedButton(
                onPressed: _running ? null : _delete,
                child: const Text(modelDownloadDeleteLabel),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
