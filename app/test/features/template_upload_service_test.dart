import 'dart:convert';

import 'package:consentlink/features/templates/template_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _TestClient extends http.BaseClient {
  _TestClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

http.StreamedResponse _response(String body, int statusCode) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );

const _analysisResponse = {
  'font': 'Arial',
  'size_pt': 11,
  'heading': {'font': 'Arial', 'size_pt': 13, 'bold': true},
  'line_spacing': 1.15,
  'margins_cm': [2.5, 2.5, 2.5, 2.5],
  'header': 'Institution',
  'footer': 'Page x of y',
  'logo_path': null,
  'columns': <String>[],
  'confidence': {
    'font': 0.95,
    'heading': 0.85,
    'line_spacing': 0.8,
    'margins_cm': 0.95,
    'footer': 0.9,
  },
  'logo_candidates': [
    {'page': 2, 'bbox': [20, 30, 80, 90], 'confidence': 0.9},
  ],
  'sections': [
    {'title': 'Purpose', 'text': 'This is extracted consent text.'},
  ],
  'storage_path': 'templates/uploads/generated.pdf',
  'detected_type': 'application/pdf',
  'size_mb': 0.01,
};

TemplateUploadService _service({
  required http.Client client,
  Future<String?> Function()? token,
  String serviceUrl = 'https://service.test',
}) => TemplateUploadService(
  serviceUrl: serviceUrl,
  accessTokenProvider: token ?? () async => 'test-user-token',
  client: client,
);

void main() {
  test('uploads the file with caller auth and parses style and sections', () async {
    var requestSeen = false;
    final client = _TestClient((request) async {
      requestSeen = true;
      expect(request.method, 'POST');
      expect(request.url.path, '/v1/templates/upload');
      expect(request, isA<http.MultipartRequest>());
      final multipart = request as http.MultipartRequest;
      expect(multipart.headers['Authorization'], 'Bearer test-user-token');
      expect(multipart.files.single.field, 'file');
      expect(multipart.files.single.filename, 'consent.pdf');
      expect(multipart.files.single.length, 4);
      return _response(jsonEncode(_analysisResponse), 200);
    });

    final result = await _service(client: client).upload(
      const TemplateUploadFile(name: 'consent.pdf', bytes: [37, 80, 68, 70]),
    );

    expect(requestSeen, isTrue);
    expect(result.storagePath, 'templates/uploads/generated.pdf');
    expect(result.fileName, 'consent.pdf');
    expect(result.rules.first.value, 'Arial 11 pt');
    expect(result.sections.single.title, 'Purpose');
    expect(result.sections.single.text, 'This is extracted consent text.');
    expect(result.logoCandidates.single['page'], 2);
  });

  test('reports the service validation error without losing its message', () async {
    final client = _TestClient(
      (_) async => _response(
        jsonEncode({
          'code': 'template_has_no_text',
          'message': 'No extractable text was found in the PDF.',
        }),
        422,
      ),
    );

    await expectLater(
      _service(client: client).upload(
        const TemplateUploadFile(name: 'scan.pdf', bytes: [37, 80, 68, 70]),
      ),
      throwsA(
        isA<TemplateUploadException>().having(
          (error) => error.message,
          'message',
          'No extractable text was found in the PDF.',
        ),
      ),
    );
  });

  test('does not send when no caller token is available', () async {
    var requestSeen = false;
    final client = _TestClient((_) async {
      requestSeen = true;
      return _response('{}', 200);
    });

    await expectLater(
      _service(client: client, token: () async => null).upload(
        const TemplateUploadFile(name: 'consent.pdf', bytes: [37, 80, 68, 70]),
      ),
      throwsA(isA<TemplateUploadException>()),
    );
    expect(requestSeen, isFalse);
  });

  test('rejects unsupported or oversized files before sending', () async {
    var requestSeen = false;
    final client = _TestClient((_) async {
      requestSeen = true;
      return _response('{}', 200);
    });
    final service = _service(client: client);

    await expectLater(
      service.upload(
        const TemplateUploadFile(name: 'consent.txt', bytes: [1]),
      ),
      throwsA(isA<TemplateUploadException>()),
    );
    await expectLater(
      service.upload(
        TemplateUploadFile(
          name: 'large.pdf',
          bytes: List<int>.filled(maxTemplateUploadBytes + 1, 0),
        ),
      ),
      throwsA(isA<TemplateUploadException>()),
    );
    expect(requestSeen, isFalse);
  });
}
