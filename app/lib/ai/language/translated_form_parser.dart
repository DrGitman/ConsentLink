import 'dart:convert';

import 'package:consentlink/contracts/languages.dart';

import '../domain/consent_element.dart';
import 'review_status.dart';
import 'translated_form.dart';

/// Thrown when a language pack form file can't be read.
final class LanguagePackFormatException implements Exception {
  const LanguagePackFormatException(this.message);

  final String message;

  @override
  String toString() => 'LanguagePackFormatException: $message';
}

/// Reads a `forms/consent-form.<code>.json` file of a language pack.
///
/// Throws a [LanguagePackFormatException] when the file is invalid.
TranslatedForm parseTranslatedForm(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw LanguagePackFormatException('Invalid JSON: ${error.message}');
  }
  final json = _asMap(decoded, 'form');
  try {
    final formReviewer = _reviewerOrNull(json['reviewer']);
    return TranslatedForm(
      id: _string(json, 'id'),
      languageCode: _languageCode(json),
      version: _string(json, 'version'),
      sections: [
        for (final section in _sectionList(json['sections']))
          _section(_asMap(section, 'section'), formReviewer),
      ],
    );
  } on ArgumentError catch (error) {
    throw LanguagePackFormatException('Invalid form: ${error.message}');
  }
}

// Some packs put the app code (`de`) in `iso639_3`, and the master file only
// has `"language": "en"`, so both lookups are tried.
String _languageCode(Map<String, Object?> json) {
  final raw = _stringOrNull(json, 'iso639_3') ?? _string(json, 'language');
  final language = languageByIso6393(raw) ?? languageByCode(raw);
  if (language == null) {
    throw LanguagePackFormatException('Unknown language "$raw"');
  }
  return language.code;
}

// An untranslated shell has `"sections": {}`.
List<Object?> _sectionList(Object? value) => switch (value) {
  final List<Object?> list => list,
  final Map<String, Object?> map when map.isEmpty => const [],
  _ => throw const LanguagePackFormatException('"sections" must be a list'),
};

TranslatedSection _section(Map<String, Object?> json, Reviewer? fallback) {
  final elementKey = _stringOrNull(json, 'required_element');
  return TranslatedSection(
    key: _string(json, 'key'),
    element: elementKey == null ? null : _element(elementKey),
    title: _string(json, 'title'),
    text: _string(json, 'text'),
    required: _field<bool>(json, 'required'),
    status: _byJsonValue(
      ReviewStatus.values,
      (status) => status.jsonValue,
      _string(json, 'status'),
    ),
    reviewer: _reviewerOrNull(json['reviewer']) ?? fallback,
  );
}

ConsentElement _element(String key) => ConsentElement.values.firstWhere(
  (element) => element.jsonKey == key,
  orElse: () => throw LanguagePackFormatException('Unknown element "$key"'),
);

// The shells carry a reviewer whose fields are all null.
Reviewer? _reviewerOrNull(Object? value) {
  if (value == null) return null;
  final json = _asMap(value, 'reviewer');
  if (json.values.every((field) => field == null)) return null;
  final date = DateTime.tryParse(_string(json, 'date'));
  if (date == null) {
    throw LanguagePackFormatException(
      'Invalid reviewer date "${json['date']}"',
    );
  }
  return Reviewer(
    name: _string(json, 'name'),
    fluency: _byJsonValue(
      ReviewerFluency.values,
      (fluency) => fluency.jsonValue,
      _string(json, 'fluency'),
    ),
    date: date,
  );
}

T _byJsonValue<T>(List<T> values, String Function(T) jsonValueOf, String raw) =>
    values.firstWhere(
      (value) => jsonValueOf(value) == raw,
      orElse: () => throw LanguagePackFormatException('Unknown value "$raw"'),
    );

Map<String, Object?> _asMap(Object? value, String name) => switch (value) {
  final Map<String, Object?> map => map,
  _ => throw LanguagePackFormatException('"$name" must be an object'),
};

String _string(Map<String, Object?> json, String key) =>
    _field<String>(json, key);

String? _stringOrNull(Map<String, Object?> json, String key) =>
    json[key] == null ? null : _string(json, key);

T _field<T>(Map<String, Object?> json, String key) => switch (json[key]) {
  final T value => value,
  null => throw LanguagePackFormatException('Missing "$key"'),
  _ => throw LanguagePackFormatException('"$key" must be a $T'),
};
