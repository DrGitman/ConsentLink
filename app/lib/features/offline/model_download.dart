import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../ai/llm/llm_model_config.dart';

/// Where the model comes from: Google's official Gemma 4 repo (Apache 2.0).
const gemmaModelUrl =
    'https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/main/'
    '$gemmaModelFileName';

/// Size on Hugging Face, shown before the download starts (3.35 GB).
const gemmaApproxBytes = 3350000000;

enum ModelDownloadPhase {
  notInstalled,
  downloading,
  paused,
  verifying,
  installed,
  failed,
}

class ModelDownloadState {
  const ModelDownloadState({
    this.phase = ModelDownloadPhase.notInstalled,
    this.received = 0,
    this.total = gemmaApproxBytes,
    this.bytesPerSecond = 0,
    this.error,
  });
  final ModelDownloadPhase phase;
  final int received;
  final int total;
  final double bytesPerSecond;
  final String? error;

  double get progress =>
      total <= 0 ? 0 : (received / total).clamp(0, 1).toDouble();

  Duration? get remaining => bytesPerSecond <= 0
      ? null
      : Duration(seconds: ((total - received) / bytesPerSecond).round());

  ModelDownloadState copyWith({
    ModelDownloadPhase? phase,
    int? received,
    int? total,
    double? bytesPerSecond,
    String? error,
  }) => ModelDownloadState(
    phase: phase ?? this.phase,
    received: received ?? this.received,
    total: total ?? this.total,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    error: error,
  );
}

/// Downloads the on-device model into the folder the AI loads it from
/// (`files/models`, see [deviceModelPath]). Resumes where it stopped (a
/// `.part` file and an HTTP Range request), and checks the finished file
/// against the SHA-256 Hugging Face publishes for it before it is used.
///
/// Amaury's model download contract can replace this class later; the
/// screen only uses [modelDownloadProvider].
class ModelDownloadController extends StateNotifier<ModelDownloadState> {
  ModelDownloadController({http.Client? client})
    : _client = client ?? http.Client(),
      super(const ModelDownloadState()) {
    _check();
  }

  final http.Client _client;
  StreamSubscription<List<int>>? _body;
  IOSink? _sink;
  var _cancelled = false;

  static Future<File> _target() async {
    final folder = await getApplicationSupportDirectory();
    final dir = await Directory(
      '${folder.path}/$modelsFolderName',
    ).create(recursive: true);
    return File('${dir.path}/$gemmaModelFileName');
  }

  Future<void> _check() async {
    final File file;
    try {
      file = await _target();
    } catch (_) {
      return; // No file system here (tests): stays "not installed".
    }
    final part = File('${file.path}.part');
    if (!mounted) return;
    if (await file.exists()) {
      state = state.copyWith(
        phase: ModelDownloadPhase.installed,
        received: await file.length(),
        total: await file.length(),
      );
    } else if (await part.exists()) {
      state = state.copyWith(
        phase: ModelDownloadPhase.paused,
        received: await part.length(),
      );
    }
  }

  bool get busy =>
      state.phase == ModelDownloadPhase.downloading ||
      state.phase == ModelDownloadPhase.verifying;

  Future<void> start() async {
    if (busy || state.phase == ModelDownloadPhase.installed) return;
    _cancelled = false;
    final file = await _target();
    final part = File('${file.path}.part');
    var have = await part.exists() ? await part.length() : 0;
    state = state.copyWith(
      phase: ModelDownloadPhase.downloading,
      received: have,
    );
    try {
      final expected = await _expectedSha256();
      final request = http.Request('GET', Uri.parse(gemmaModelUrl));
      if (have > 0) request.headers['Range'] = 'bytes=$have-';
      final response = await _client.send(request);
      if (response.statusCode == 200 && have > 0) {
        have = 0; // The server ignored the range: start over.
      } else if (response.statusCode == 416) {
        have = await part.length(); // Already complete.
      } else if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          'The download server answered ${response.statusCode}.',
        );
      }
      final length = response.contentLength;
      final total = length == null ? state.total : have + length;
      if (response.statusCode != 416) {
        _sink = part.openWrite(
          mode: have == 0 ? FileMode.write : FileMode.append,
        );
        var received = have;
        var windowStart = DateTime.now();
        var windowBytes = 0;
        final done = Completer<void>();
        _body = response.stream.listen(
          (chunk) {
            _sink!.add(chunk);
            received += chunk.length;
            windowBytes += chunk.length;
            final ms = DateTime.now().difference(windowStart).inMilliseconds;
            if (ms >= 1000 && mounted) {
              state = state.copyWith(
                received: received,
                total: total,
                bytesPerSecond: windowBytes * 1000 / ms,
              );
              windowStart = DateTime.now();
              windowBytes = 0;
            }
          },
          onError: done.completeError,
          onDone: done.complete,
          cancelOnError: true,
        );
        await done.future;
        await _sink!.flush();
        await _sink!.close();
        _sink = null;
        if (_cancelled) return;
        if (length != null && received < total) {
          throw const HttpException(
            'The connection was cut. Tap Resume to continue.',
          );
        }
      }
      if (!mounted) return;
      state = state.copyWith(phase: ModelDownloadPhase.verifying);
      if (!await _intact(part, expected)) {
        await part.delete();
        throw const FileSystemException(
          'The downloaded file is damaged, so it was removed. Download it again.',
        );
      }
      await part.rename(file.path);
      if (!mounted) return;
      final size = await file.length();
      state = state.copyWith(
        phase: ModelDownloadPhase.installed,
        received: size,
        total: size,
      );
    } catch (e) {
      await _sink?.close();
      _sink = null;
      if (!mounted || _cancelled) return;
      final part2 = File('${file.path}.part');
      state = state.copyWith(
        phase: ModelDownloadPhase.failed,
        received: await part2.exists() ? await part2.length() : 0,
        error: e is SocketException
            ? 'No internet connection. Connect to Wi-Fi and tap Resume.'
            : e is HttpException
            ? e.message
            : e is FileSystemException
            ? e.message
            : 'The download stopped. Tap Resume to continue.',
      );
    }
  }

  /// Stops the transfer; the part already downloaded is kept for Resume.
  Future<void> pause() async {
    if (state.phase != ModelDownloadPhase.downloading) return;
    _cancelled = true;
    await _body?.cancel();
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    final part = File('${(await _target()).path}.part');
    if (!mounted) return;
    state = state.copyWith(
      phase: ModelDownloadPhase.paused,
      received: await part.exists() ? await part.length() : state.received,
    );
  }

  /// Removes the model (or a partial download) to free space.
  Future<void> remove() async {
    await pause();
    final file = await _target();
    for (final f in [file, File('${file.path}.part')]) {
      if (await f.exists()) await f.delete();
    }
    if (mounted) state = const ModelDownloadState();
  }

  /// The SHA-256 Hugging Face lists for the file (its LFS etag), or null.
  Future<String?> _expectedSha256() async {
    try {
      final head = await _client.head(Uri.parse(gemmaModelUrl));
      final etag = head.headers['x-linked-etag'] ?? head.headers['etag'];
      final hex = etag?.replaceAll('"', '').replaceAll('W/', '');
      return hex != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)
          ? hex
          : null;
    } catch (_) {
      return null;
    }
  }

  /// The file hashes to [expected]; without a published hash, it must at
  /// least be a GGUF file.
  static Future<bool> _intact(File part, String? expected) async {
    if (expected != null) {
      final path = part.path;
      // 3 GB of hashing runs off the UI thread.
      final digest = await Isolate.run(
        () async => (await sha256.bind(File(path).openRead()).first).toString(),
      );
      return digest == expected;
    }
    final head = await part.openRead(0, 4).expand((b) => b).toList();
    return String.fromCharCodes(head) == 'GGUF';
  }

  @override
  void dispose() {
    _body?.cancel();
    _sink?.close();
    _client.close();
    super.dispose();
  }
}

/// App wide, so the download keeps going after leaving the screen.
final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadController, ModelDownloadState>(
      (ref) => ModelDownloadController(),
    );
