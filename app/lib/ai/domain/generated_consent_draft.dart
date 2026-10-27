import 'package:flutter/foundation.dart';

import 'consent_element.dart';
import 'generated_section.dart';

/// A consent form drafted by the AI from one proposal (Figma G).
///
/// Mirrors `/schemas/consent_draft.schema.json`.
final class GeneratedConsentDraft {
  /// Throws an [ArgumentError] when a field breaks the schema rules.
  GeneratedConsentDraft({
    required this.formLanguage,
    required this.readingGrade,
    required List<GeneratedSection> sections,
    required List<ConsentElement> missing,
  }) : sections = List.unmodifiable(sections),
       missing = List.unmodifiable(missing) {
    if (formLanguage.trim().isEmpty) {
      throw ArgumentError.value(formLanguage, 'formLanguage', 'Is blank');
    }
    _checkReadingGrade();
    _checkElements();
  }

  // Free text until the team picks one language code system (BLOCKED #12).
  final String formLanguage;

  /// School grade needed to read the form, or `null` when not measured.
  final double? readingGrade;
  final List<GeneratedSection> sections;

  /// Required elements the AI could not write a section for.
  final List<ConsentElement> missing;

  void _checkReadingGrade() {
    final grade = readingGrade;
    if (grade != null && (!grade.isFinite || grade < 0)) {
      throw RangeError.value(grade, 'readingGrade', 'Must be finite and >= 0');
    }
  }

  void _checkElements() {
    final drafted = sections.map((section) => section.element).toList();
    if (drafted.toSet().length != drafted.length) {
      throw ArgumentError.value(drafted, 'sections', 'One section per element');
    }
    if (missing.toSet().length != missing.length) {
      throw ArgumentError.value(missing, 'missing', 'Has duplicates');
    }
    final both = missing.where(drafted.contains);
    if (both.isNotEmpty) {
      throw ArgumentError.value(
        both.toList(),
        'missing',
        'Already drafted in sections',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GeneratedConsentDraft &&
      other.formLanguage == formLanguage &&
      other.readingGrade == readingGrade &&
      listEquals(other.sections, sections) &&
      listEquals(other.missing, missing);

  @override
  int get hashCode => Object.hash(
    formLanguage,
    readingGrade,
    Object.hashAll(sections),
    Object.hashAll(missing),
  );
}
