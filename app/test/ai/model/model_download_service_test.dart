import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/model/model_download_service.dart';
import 'package:consentlink/ai/model/model_source.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Invented "model": no real weights in tests.
final _bytes = utf8.encode('Invented model bytes for the download test.');
const _fileName = 'invented.gguf';
final _source = ModelSource(
  url: 'https://example.invalid/$_fileName',
  fileName: _fileName,
  sizeBytes: _bytes.length,
  sha256: sha256.convert(_bytes).toString(),
);

/// Serves [_bytes], honouring `range`; records the range of each request.
MockClient _server(List<String?> ranges, {int status = HttpStatus.ok}) =>
    MockClient.streaming((request, _) async {
      final range = request.headers['range'];
      ranges.add(range);
      if (status != HttpStatus.ok) {
        return http.StreamedResponse(const Stream.empty(), status);
      }
      final start = range == null
          ? 0
          : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
      return http.StreamedResponse(
        Stream.value(_bytes.sublist(start)),
        range == null ? HttpStatus.ok : HttpStatus.partialContent,
      );
    });

void main() {
  late Directory folder;
  File file(String name) => File('${folder.path}/$name');

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('model_download_test');
  });
  tearDown(() => folder.delete(recursive: true));

  ModelDownloadService service(http.Client client, {ModelSource? source}) =>
      ModelDownloadService(
        client: client,
        modelsFolder: () async => folder,
        source: source ?? _source,
      );

  test('downloads, checks and saves the model under its final name', () async {
    final ranges = <String?>[];
    final events = await service(_server(ranges)).download().toList();

    expect(
      events.map((e) => e.phase).toSet(),
      ModelDownloadPhase.values.toSet(),
    );
    expect(events.last.fraction, 1);
    expect(file(_fileName).readAsBytesSync(), _bytes);
    expect(file('$_fileName.part').existsSync(), isFalse);
    expect(await service(_server(ranges)).isDownloaded(), isTrue);
    expect(ranges, [null]);
  });

  test('resumes from the .part file', () async {
    file('$_fileName.part').writeAsBytesSync(_bytes.sublist(0, 10));
    final ranges = <String?>[];

    await service(_server(ranges)).download().drain<void>();

    expect(ranges, ['bytes=10-']);
    expect(file(_fileName).readAsBytesSync(), _bytes);
  });

  test('does nothing when the model is already there', () async {
    file(_fileName).writeAsBytesSync(_bytes);
    final ranges = <String?>[];

    final events = await service(_server(ranges)).download().toList();

    expect(events.single.phase, ModelDownloadPhase.done);
    expect(ranges, isEmpty);
  });

  test('deletes the model and any partial download', () async {
    file(_fileName).writeAsBytesSync(_bytes);
    file('$_fileName.part').writeAsBytesSync(_bytes.sublist(0, 3));

    await service(_server([])).deleteModel();

    expect(file(_fileName).existsSync(), isFalse);
    expect(file('$_fileName.part').existsSync(), isFalse);
    await service(_server([])).deleteModel();
  });

  test('a wrong checksum deletes the file and fails', () async {
    final damaged = ModelSource(
      url: _source.url,
      fileName: _fileName,
      sizeBytes: _bytes.length,
      sha256: '0' * 64,
    );

    await expectLater(
      service(_server([]), source: damaged).download(),
      emitsThrough(_failure(ModelDownloadFailure.checksum)),
    );
    expect(file(_fileName).existsSync(), isFalse);
    expect(file('$_fileName.part').existsSync(), isFalse);
  });

  test('a server error fails without a model', () async {
    await expectLater(
      service(_server([], status: HttpStatus.notFound)).download(),
      emitsInOrder([_failure(ModelDownloadFailure.server), emitsDone]),
    );
    expect(await service(_server([])).isDownloaded(), isFalse);
  });

  test('a cut connection fails and keeps the bytes for a resume', () async {
    final client = MockClient.streaming((request, _) async {
      final cut = StreamController<List<int>>()
        ..add(_bytes.sublist(0, 7))
        ..addError(http.ClientException('Invented cut.'))
        ..close();
      return http.StreamedResponse(cut.stream, HttpStatus.ok);
    });

    await expectLater(
      service(client).download(),
      emitsThrough(
        emitsInOrder([_failure(ModelDownloadFailure.network), emitsDone]),
      ),
    );
    expect(file('$_fileName.part').lengthSync(), 7);
  });
}

Matcher _failure(ModelDownloadFailure failure) => emitsError(
  isA<ModelDownloadException>().having((e) => e.failure, 'failure', failure),
);
