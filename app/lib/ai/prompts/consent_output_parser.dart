import 'dart:convert';

import 'package:consentlink/contracts/languages.dart' show languageByCode;
import 'package:consentlink/contracts/models.dart' show Confidence;

import '../ai_exceptions.dart';
import '../domain/consent_element.dart';
import '../domain/generated_consent_draft.dart';
import '../domain/generated_section.dart';

/// A draft read from the model, and the problems that were tolerated.
final class ParsedDraft {
  ParsedDraft({required this.draft, required List<String> issues})
    : issues = List.unmodifiable(issues);

  final GeneratedConsentDraft draft;

  /// Dropped sections and ignored fields, for logs; never form text.
  final List<String> issues;
}

const _rootFields = {'form_language', 'reading_grade', 'sections', 'missing'};
const _sectionFields = {
  'key',
  'title',
  'text',
  'source_pages',
  'source_quote',
  'changes',
  'confidence',
  'source',
};

/// Reads the model's output as `/schemas/consent_draft.schema.json`.
///
/// A broken root throws an [InvalidModelOutputException]. A broken section is
/// dropped, its element is added to `missing` and the problem goes in
/// [ParsedDraft.issues] (decision D5.2). Text around the JSON object, such as
/// a Markdown fence, is ignored (D5.3).
ParsedDraft parseConsentDraft(String output) {
  final json = switch (_decode(_jsonObjectIn(output))) {
    final Map<String, Object?> map => map,
    _ => throw const InvalidModelOutputException(
      'The output must be an object.',
    ),
  };
  final issues = <String>[
    for (final field in json.keys)
      if (!_rootFields.contains(field)) 'Ignored unknown field "$field".',
  ];

  final sections = <GeneratedSection>[];
  final dropped = <ConsentElement>{};
  final rawSections = _field<List<Object?>>(json, 'sections');
  for (final (index, raw) in rawSections.indexed) {
    final element = switch (raw) {
      {'key': final String key} => _elementByKey(key),
      _ => null,
    };
    try {
      final section = _section(raw, issues);
      if (sections.any((kept) => kept.element == section.element)) {
        throw const _InvalidSection('Duplicate key.');
      }
      sections.add(section);
    } on _InvalidSection catch (error) {
      issues.add('Section ${index + 1} dropped: ${error.message}');
      if (element != null) dropped.add(element);
    }
  }

  final drafted = sections.map((section) => section.element).toSet();
  final missing = {..._missing(json, issues), ...dropped}..removeAll(drafted);
  try {
    return ParsedDraft(
      draft: GeneratedConsentDraft(
        formLanguage: _formLanguage(json),
        readingGrade: _readingGrade(json),
        sections: sections,
        missing: missing.toList(),
      ),
      issues: issues,
    );
  } on ArgumentError catch (error) {
    throw InvalidModelOutputException(
      'Invalid "${error.name ?? 'draft'}": ${error.message}.',
    );
  }
}

String _jsonObjectIn(String output) {
  final start = output.indexOf('{');
  final end = output.lastIndexOf('}');
  if (start < 0 || end < start) {
    throw const InvalidModelOutputException('No JSON object in the output.');
  }
  return output.substring(start, end + 1);
}

Object? _decode(String source) {
  try {
    return jsonDecode(source);
  } on FormatException {
    throw const InvalidModelOutputException('The output is not valid JSON.');
  }
}

String _formLanguage(Map<String, Object?> json) {
  final code = _field<String>(json, 'form_language');
  if (languageByCode(code) == null) {
    throw const InvalidModelOutputException('Unknown "form_language".');
  }
  return code;
}

double? _readingGrade(Map<String, Object?> json) =>
    switch (json['reading_grade']) {
      null => null,
      final num grade => grade.toDouble(),
      _ => throw const InvalidModelOutputException(
        '"reading_grade" must be a number.',
      ),
    };

List<ConsentElement> _missing(Map<String, Object?> json, List<String> issues) {
  final keys = _field<List<Object?>>(json, 'missing');
  final elements = [
    for (final key in keys)
      if (key is String) ?_elementByKey(key),
  ];
  if (elements.length < keys.length) {
    issues.add('Ignored unknown keys in "missing".');
  }
  return elements;
}

GeneratedSection _section(Object? json, List<String> issues) {
  if (json is! Map<String, Object?>) {
    throw const _InvalidSection('A section must be an object.');
  }
  final element = _elementByKey(_sectionField<String>(json, 'key'));
  if (element == null) throw const _InvalidSection('Unknown key.');
  for (final field in json.keys) {
    if (!_sectionFields.contains(field)) {
      issues.add('Ignored unknown field "$field" in ${element.jsonKey}.');
    }
  }
  try {
    return GeneratedSection(
      element: element,
      title: _sectionField<String>(json, 'title'),
      text: _sectionField<String>(json, 'text'),
      sourcePages: _listOf<int>(json, 'source_pages'),
      sourceQuote: _optional<String>(json, 'source_quote'),
      changes: _listOf<String>(json, 'changes'),
      confidence: _byName(Confidence.values, json, 'confidence'),
      source: json['source'] == null
          ? SectionSource.proposal
          : _byName(SectionSource.values, json, 'source'),
    );
  } on ArgumentError catch (error) {
    throw _InvalidSection('"${error.name ?? 'section'}": ${error.message}.');
  }
}

ConsentElement? _elementByKey(String key) => ConsentElement.values
    .where((element) => element.jsonKey == key)
    .firstOrNull;

T _byName<T extends Enum>(
  List<T> values,
  Map<String, Object?> json,
  String field,
) =>
    values.asNameMap()[_sectionField<String>(json, field)] ??
    (throw _InvalidSection('Unknown "$field".'));

List<T> _listOf<T>(Map<String, Object?> json, String field) {
  final list = _sectionField<List<Object?>>(json, field);
  if (list.any((item) => item is! T)) {
    throw _InvalidSection('"$field" must only hold ${T}s.');
  }
  return list.cast<T>();
}

T? _optional<T>(Map<String, Object?> json, String field) =>
    json[field] == null ? null : _sectionField<T>(json, field);

T _sectionField<T>(Map<String, Object?> json, String field) =>
    switch (json[field]) {
      final T value => value,
      null => throw _InvalidSection('Missing "$field".'),
      _ => throw _InvalidSection('"$field" must be a $T.'),
    };

T _field<T>(Map<String, Object?> json, String field) => switch (json[field]) {
  final T value => value,
  null => throw InvalidModelOutputException('Missing "$field".'),
  _ => throw InvalidModelOutputException('"$field" must be a $T.'),
};

/// A section the parser drops; never leaves this file.
final class _InvalidSection implements Exception {
  const _InvalidSection(this.message);

  final String message;
}
