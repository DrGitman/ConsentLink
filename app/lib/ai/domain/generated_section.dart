import 'package:consentlink/contracts/models.dart' show Confidence;
import 'package:flutter/foundation.dart';

import 'consent_element.dart';

/// Where the text of a section comes from.
enum SectionSource { proposal, template }

const firstPageNumber = 1;

/// One consent section drafted by the AI, before any human review (Figma G).
///
/// Mirrors a `section` of `/schemas/consent_draft.schema.json`.
final class GeneratedSection {
  /// Throws an [ArgumentError] when a field breaks the schema rules.
  GeneratedSection({
    required this.element,
    required this.title,
    required this.text,
    required List<int> sourcePages,
    this.sourceQuote,
    required List<String> changes,
    required this.confidence,
    this.source = SectionSource.proposal,
  }) : sourcePages = List.unmodifiable(sourcePages),
       changes = List.unmodifiable(changes) {
    _requireNotBlank(title, 'title');
    _requireNotBlank(text, 'text');
    final quote = sourceQuote;
    if (quote != null) _requireNotBlank(quote, 'sourceQuote');
    for (final change in changes) {
      _requireNotBlank(change, 'changes');
    }
    _checkSourcePages();
  }

  final ConsentElement element;
  final String title;
  final String text;

  /// Pages of the uploaded proposal, starting at [firstPageNumber].
  ///
  /// Empty only when [source] is [SectionSource.template].
  final List<int> sourcePages;

  /// Exact text from the proposal, shown on the "Why?" sheet.
  final String? sourceQuote;

  /// What the AI changed from the source, one entry per change.
  final List<String> changes;
  final Confidence confidence;
  final SectionSource source;

  void _checkSourcePages() {
    for (final page in sourcePages) {
      if (page < firstPageNumber) {
        throw RangeError.value(page, 'sourcePages', 'Pages start at 1');
      }
    }
    if (sourcePages.toSet().length != sourcePages.length) {
      throw ArgumentError.value(sourcePages, 'sourcePages', 'Has duplicates');
    }
    if (source == SectionSource.proposal && sourcePages.isEmpty) {
      throw ArgumentError.value(
        sourcePages,
        'sourcePages',
        'Must not be empty when the source is the proposal',
      );
    }
  }

  static void _requireNotBlank(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be blank');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GeneratedSection &&
      other.element == element &&
      other.title == title &&
      other.text == text &&
      listEquals(other.sourcePages, sourcePages) &&
      other.sourceQuote == sourceQuote &&
      listEquals(other.changes, changes) &&
      other.confidence == confidence &&
      other.source == source;

  @override
  int get hashCode => Object.hash(
    element,
    title,
    text,
    Object.hashAll(sourcePages),
    sourceQuote,
    Object.hashAll(changes),
    confidence,
    source,
  );
}
