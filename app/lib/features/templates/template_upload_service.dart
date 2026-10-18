import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'template_data.dart';

const int maxTemplateUploadBytes = 25 * 1024 * 1024;
const Duration templateUploadTimeout = Duration(seconds: 30);

class TemplateUploadFile {
  const TemplateUploadFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

class TemplateUploadException implements Exception {
  const TemplateUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TemplateUploadResult {
  const TemplateUploadResult({
    required this.fileName,
    required this.storagePath,
    required this.detectedType,
    required this.styleSpec,
    required this.confidence,
    required this.sections,
    required this.logoCandidates,
  });

  factory TemplateUploadResult.fromJson(
    Map<String, Object?> json, {
    required String fileName,
  }) {
    final heading = json['heading'];
    final confidenceValue = json['confidence'];
    final sectionValues = json['sections'];
    final logoValues = json['logo_candidates'];
    if (heading is! Map ||
        confidenceValue is! Map ||
        sectionValues is! List ||
        logoValues is! List ||
        json['storage_path'] is! String ||
        json['detected_type'] is! String) {
      throw const TemplateUploadException(
        'The service returned an invalid template analysis.',
      );
    }

    final sections = <TemplateSection>[];
    for (final (index, value) in sectionValues.indexed) {
      if (value is! Map ||
          value['title'] is! String ||
          value['text'] is! String) {
        throw const TemplateUploadException(
          'The service returned an invalid template analysis.',
        );
      }
      sections.add(
        TemplateSection(
          key: 'uploaded-$index',
          title: value['title'] as String,
          text: value['text'] as String,
        ),
      );
    }

    final logoCandidates = <Map<String, Object?>>[];
    for (final value in logoValues) {
      if (value is! Map ||
          value['page'] is! num ||
          value['bbox'] is! List ||
          value['confidence'] is! num) {
        throw const TemplateUploadException(
          'The service returned an invalid template analysis.',
        );
      }
      logoCandidates.add(Map<String, Object?>.from(value));
    }

    final confidence = <String, double>{};
    for (final entry in confidenceValue.entries) {
      if (entry.key is! String || entry.value is! num) {
        throw const TemplateUploadException(
          'The service returned an invalid template analysis.',
        );
      }
      confidence[entry.key as String] = (entry.value as num).toDouble();
    }

    return TemplateUploadResult(
      fileName: fileName,
      storagePath: json['storage_path'] as String,
      detectedType: json['detected_type'] as String,
      styleSpec: {
        'font': json['font'],
        'size_pt': json['size_pt'],
        'heading': Map<String, Object?>.from(heading),
        'line_spacing': json['line_spacing'],
        'margins_cm': json['margins_cm'],
        'header': json['header'],
        'footer': json['footer'],
        'logo_path': json['logo_path'],
        'columns': json['columns'],
      },
      confidence: confidence,
      sections: sections,
      logoCandidates: logoCandidates,
    );
  }

  final String fileName;
  final String storagePath;
  final String detectedType;
  final Map<String, Object?> styleSpec;
  final Map<String, double> confidence;
  final List<TemplateSection> sections;
  final List<Map<String, Object?>> logoCandidates;

  List<TemplateRule> get rules {
    final heading = styleSpec['heading']! as Map<String, Object?>;
    String field(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : '';
    String fontSize(Object? font, Object? size) {
      final name = field(font);
      final points = size is num ? '${size.toStringAsFixed(0)} pt' : '';
      if (name.isEmpty && points.isEmpty) return 'Not detected';
      if (name.isEmpty) return points;
      return points.isEmpty ? name : '$name $points';
    }

    String confidenceLabel(String key) {
      final value = confidence[key] ?? 0;
      if (value >= 0.8) return 'High';
      if (value > 0) return 'Medium';
      return 'Low';
    }

    final marginsValue = styleSpec['margins_cm'];
    final margins = marginsValue is List
        ? marginsValue.whereType<num>().map((value) => value.toDouble()).toList()
        : <double>[];
    final marginText = margins.isEmpty
        ? 'Not detected'
        : margins.every((value) => value == margins.first)
        ? '${margins.first.toStringAsFixed(1)} cm all sides'
        : '${margins.map((value) => value.toStringAsFixed(1)).join(" / ")} cm '
              '(top / right / bottom / left)';
    final lineSpacing = styleSpec['line_spacing'];
    final header = field(styleSpec['header']);
    final footer = field(styleSpec['footer']);
    final columnsValue = styleSpec['columns'];
    final columns = columnsValue is List
        ? columnsValue.whereType<String>().toList()
        : <String>[];

    return [
      TemplateRule(
        key: 'body',
        title: 'Body font',
        value: fontSize(styleSpec['font'], styleSpec['size_pt']),
        icon: 'form/type',
        confidence: confidenceLabel('font'),
      ),
      TemplateRule(
        key: 'headings',
        title: 'Headings',
        value: fontSize(heading['font'], heading['size_pt']) +
            (heading['bold'] == true ? ' Bold' : ''),
        icon: 'form/type',
        confidence: confidenceLabel('heading'),
      ),
      TemplateRule(
        key: 'spacing',
        title: 'Line spacing',
        value: lineSpacing is num
            ? lineSpacing.toStringAsFixed(2)
            : 'Not detected',
        icon: 'form/textsize',
        confidence: confidenceLabel('line_spacing'),
      ),
      TemplateRule(
        key: 'margins',
        title: 'Margins',
        value: marginText,
        icon: 'layers',
        confidence: confidenceLabel('margins_cm'),
      ),
      TemplateRule(
        key: 'footer',
        title: 'Header and footer',
        value: [
          if (header.isNotEmpty) 'Header: $header',
          if (footer.isNotEmpty) 'Footer: $footer',
          if (header.isEmpty && footer.isEmpty) 'Not detected',
        ].join(' · '),
        icon: 'responses/file',
        confidence: confidenceLabel('footer'),
      ),
      TemplateRule(
        key: 'columns',
        title: 'Columns',
        value: columns.isEmpty ? 'Not detected' : columns.join(' | '),
        icon: 'form/textsize',
        confidence: confidenceLabel('columns'),
      ),
      const TemplateRule(
        key: 'languages',
        title: 'Languages',
        value: 'Set after review',
        icon: 'form/globe',
      ),
    ];
  }
}

typedef TemplateAccessTokenProvider = Future<String?> Function();
typedef TemplateFilePicker = Future<TemplateUploadFile?> Function();
typedef TemplateUpload = Future<TemplateUploadResult> Function(
  TemplateUploadFile file,
);

final templateServiceUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment('TEMPLATE_SERVICE_URL'),
);

final templateAccessTokenProvider = Provider<TemplateAccessTokenProvider>(
  (ref) => () async => null,
);

final templateHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final templateFilePickerProvider = Provider<TemplateFilePicker>(
  (ref) => _pickTemplateFile,
);

final templateUploadServiceProvider = Provider<TemplateUploadService>(
  (ref) => TemplateUploadService(
    serviceUrl: ref.watch(templateServiceUrlProvider),
    accessTokenProvider: ref.watch(templateAccessTokenProvider),
    client: ref.watch(templateHttpClientProvider),
  ),
);

final templateUploadProvider = Provider<TemplateUpload>(
  (ref) => ref.watch(templateUploadServiceProvider).upload,
);

final uploadedTemplateProvider = StateProvider<TemplateUploadResult?>(
  (ref) => null,
);

class TemplateUploadService {
  const TemplateUploadService({
    required this.serviceUrl,
    required this.accessTokenProvider,
    required this.client,
  });

  final String serviceUrl;
  final TemplateAccessTokenProvider accessTokenProvider;
  final http.Client client;

  Future<TemplateUploadResult> upload(TemplateUploadFile file) async {
    final extension = file.name.split('.').last.toLowerCase();
    if (!const {'pdf', 'docx'}.contains(extension)) {
      throw const TemplateUploadException(
        'Choose a PDF or DOCX template file.',
      );
    }
    if (file.bytes.isEmpty) {
      throw const TemplateUploadException('The selected file is empty.');
    }
    if (file.bytes.length > maxTemplateUploadBytes) {
      throw const TemplateUploadException(
        'The template exceeds the 25 MB upload limit.',
      );
    }

    final serviceUri = Uri.tryParse(serviceUrl.trim());
    if (serviceUri == null ||
        !const {'http', 'https'}.contains(serviceUri.scheme) ||
        serviceUri.host.isEmpty) {
      throw const TemplateUploadException(
        'Template service is not configured.',
      );
    }
    final token = (await accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const TemplateUploadException(
        'Template upload authentication is not configured in this build.',
      );
    }

    final endpoint = serviceUri.replace(
      path: '${serviceUri.path.replaceFirst(RegExp(r'/+$'), '')}'
          '/v1/templates/upload',
      query: null,
      fragment: null,
    );
    final request = http.MultipartRequest('POST', endpoint)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes,
          filename: file.name,
        ),
      );

    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(templateUploadTimeout);
      final decoded = _decodeObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TemplateUploadException(
          _errorMessage(response.statusCode, decoded),
        );
      }
      return TemplateUploadResult.fromJson(decoded, fileName: file.name);
    } on TemplateUploadException {
      rethrow;
    } on TimeoutException {
      throw const TemplateUploadException(
        'The template service took too long to respond. Try again.',
      );
    } on http.ClientException {
      throw const TemplateUploadException(
        'Could not reach the template service. Check the connection and try again.',
      );
    } on FormatException {
      throw const TemplateUploadException(
        'The template service returned an invalid response.',
      );
    }
  }
}

Future<TemplateUploadFile?> _pickTemplateFile() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const TemplateUploadException(
        'Could not read the selected file. Choose another file and try again.',
      );
    }
    return TemplateUploadFile(name: file.name, bytes: bytes);
  } on PlatformException {
    throw const TemplateUploadException(
      'Could not open the file picker. Try again.',
    );
  }
}

Map<String, Object?> _decodeObject(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object.');
  }
  return Map<String, Object?>.from(decoded);
}

String _errorMessage(int statusCode, Map<String, Object?>? body) {
  final message = body?['message'];
  if (message is String && message.trim().isNotEmpty) return message;
  if (statusCode == 401 || statusCode == 403) {
    return 'Your sign-in has expired or does not allow this upload.';
  }
  if (statusCode == 413) return 'The template exceeds the 25 MB upload limit.';
  if (statusCode >= 500) {
    return 'The template service could not process the file. Try again later.';
  }
  return 'The template could not be uploaded. Check the file and try again.';
}
