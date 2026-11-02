import 'dart:developer' show log;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../ai_exceptions.dart';
import 'model_source.dart';

const _partSuffix = '.part';
const _logName = 'ai.model';
const _percent = 100;

enum ModelDownloadPhase { downloading, verifying, done }

/// One step of a model download.
final class ModelDownloadProgress {
  const ModelDownloadProgress(this.phase, this.receivedBytes, this.totalBytes);

  final ModelDownloadPhase phase;
  final int receivedBytes;
  final int totalBytes;

  double get fraction => totalBytes == 0 ? 0 : receivedBytes / totalBytes;
}

/// Downloads the on-device model into the app's `files/models` folder.
///
/// Bytes go to a `.part` file first, so a cut or a cancel resumes where it
/// stopped. The file only gets its final name once its SHA-256 matches.
/// The network policy (Wi-Fi only) is the caller's choice (decision DM.2).
final class ModelDownloadService {
  const ModelDownloadService({
    required this.client,
    required this.modelsFolder,
    this.source = gemmaModelSource,
  });

  final http.Client client;
  final Future<Directory> Function() modelsFolder;
  final ModelSource source;

  /// True when the model file is in place with its expected size.
  Future<bool> isDownloaded() async {
    final file = await _target();
    return file.existsSync() && await file.length() == source.sizeBytes;
  }

  /// Deletes the model and any partial download, to free about 3 GB.
  Future<void> deleteModel() async {
    final target = await _target();
    try {
      for (final file in [target, File('${target.path}$_partSuffix')]) {
        if (file.existsSync()) await file.delete();
      }
    } on FileSystemException catch (error) {
      throw ModelDownloadException(
        ModelDownloadFailure.storage,
        'Cannot delete the model: ${error.osError?.message ?? error.message}',
      );
    }
    log('Model deleted: ${source.fileName}', name: _logName);
  }

  /// Emits progress at most once per percent, then [ModelDownloadPhase.done].
  /// Failures are [ModelDownloadException] errors. Cancelling keeps the
  /// `.part` file for the next try.
  Stream<ModelDownloadProgress> download() async* {
    final total = source.sizeBytes;
    if (await isDownloaded()) {
      yield ModelDownloadProgress(ModelDownloadPhase.done, total, total);
      return;
    }
    final target = await _target();
    final part = File('${target.path}$_partSuffix');
    try {
      await part.parent.create(recursive: true);
      var received = part.existsSync() ? await part.length() : 0;
      if (received > total) received = await _restart(part);
      if (received < total) {
        // Not yield*: it would forward a failure and carry on to verify.
        await for (final progress in _fetch(part, received)) {
          yield progress;
        }
      }
      yield ModelDownloadProgress(ModelDownloadPhase.verifying, total, total);
      await _verify(part);
      await part.rename(target.path);
      log('Model saved: ${source.fileName}', name: _logName);
      yield ModelDownloadProgress(ModelDownloadPhase.done, total, total);
    } on FileSystemException catch (error) {
      throw ModelDownloadException(
        ModelDownloadFailure.storage,
        'Cannot write the model: ${error.osError?.message ?? error.message}',
      );
    }
  }

  Stream<ModelDownloadProgress> _fetch(File part, int alreadyReceived) async* {
    final total = source.sizeBytes;
    var received = alreadyReceived;
    final request = http.Request('GET', Uri.parse(source.url));
    if (received > 0) request.headers['range'] = 'bytes=$received-';
    final response = await _send(request);
    if (response.statusCode == HttpStatus.ok && received > 0) {
      // The server ignored the range: start over.
      received = await _restart(part);
    } else if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw ModelDownloadException(
        ModelDownloadFailure.server,
        'The server answered ${response.statusCode}.',
      );
    }
    log('Download from byte $received of $total', name: _logName);
    final sink = part.openWrite(mode: FileMode.append);
    var lastPercent = -1;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        final percent = received * _percent ~/ total;
        if (percent != lastPercent) {
          lastPercent = percent;
          yield ModelDownloadProgress(
            ModelDownloadPhase.downloading,
            received,
            total,
          );
        }
      }
    } on http.ClientException catch (error) {
      throw _networkError(error.message);
    } on SocketException catch (error) {
      throw _networkError(error.message);
    } finally {
      await sink.close();
    }
    if (received != total) {
      throw _networkError('Stopped at $received of $total bytes.');
    }
  }

  Future<http.StreamedResponse> _send(http.Request request) async {
    try {
      return await client.send(request);
    } on http.ClientException catch (error) {
      throw _networkError(error.message);
    } on SocketException catch (error) {
      throw _networkError(error.message);
    }
  }

  Future<void> _verify(File part) async {
    final digest = await sha256.bind(part.openRead()).first;
    if (digest.toString() != source.sha256) {
      await part.delete();
      throw const ModelDownloadException(
        ModelDownloadFailure.checksum,
        'The downloaded model is damaged; it was deleted.',
      );
    }
  }

  Future<int> _restart(File part) async {
    await part.writeAsBytes(const []);
    return 0;
  }

  Future<File> _target() async =>
      File('${(await modelsFolder()).path}/${source.fileName}');

  static ModelDownloadException _networkError(String detail) =>
      ModelDownloadException(ModelDownloadFailure.network, detail);
}
