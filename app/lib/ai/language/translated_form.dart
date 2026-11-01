import '../domain/consent_element.dart';
import 'review_status.dart';

/// One section of a consent form translated into a participant language.
final class TranslatedSection {
  /// Throws an [ArgumentError] when a field is blank, or when a reviewed
  /// section has no reviewer allowed to approve it.
  TranslatedSection({
    required this.key,
    this.element,
    required this.title,
    required this.text,
    required this.required,
    required this.status,
    this.reviewer,
  }) {
    _requireNotBlank(key, 'key');
    _requireNotBlank(title, 'title');
    _requireNotBlank(text, 'text');
    if (status == ReviewStatus.reviewed && !_canApprove(reviewer)) {
      throw ArgumentError.value(
        reviewer?.fluency,
        'reviewer',
        'A reviewed section needs a first-language or fluent reviewer',
      );
    }
  }

  final String key;

  /// The required element this section covers, if any.
  final ConsentElement? element;
  final String title;
  final String text;
  final bool required;
  final ReviewStatus status;
  final Reviewer? reviewer;

  bool get isParticipantFacing => status.isParticipantFacing;

  /// Returns this section marked reviewed by [by].
  ///
  /// Throws an [ArgumentError] when [by] is a learner.
  TranslatedSection markReviewed(Reviewer by) => TranslatedSection(
    key: key,
    element: element,
    title: title,
    text: text,
    required: required,
    status: ReviewStatus.reviewed,
    reviewer: by,
  );

  static bool _canApprove(Reviewer? reviewer) =>
      reviewer != null && reviewer.fluency.canApprove;

  static void _requireNotBlank(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be blank');
    }
  }
}

/// A consent form in one participant language, section by section.
final class TranslatedForm {
  /// Throws an [ArgumentError] when a field is blank or a key repeats.
  TranslatedForm({
    required this.id,
    required this.languageCode,
    required this.version,
    required List<TranslatedSection> sections,
  }) : sections = List.unmodifiable(sections) {
    for (final (value, name) in [
      (id, 'id'),
      (languageCode, 'languageCode'),
      (version, 'version'),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'Is blank');
      }
    }
    final keys = sections.map((section) => section.key).toSet();
    if (keys.length != sections.length) {
      throw ArgumentError.value(sections, 'sections', 'One section per key');
    }
  }

  final String id;

  /// The app language code (BCP 47, see `contracts/languages.dart`).
  final String languageCode;
  final String version;
  final List<TranslatedSection> sections;

  /// Sections that may be shown to a participant.
  List<TranslatedSection> get participantSections =>
      sections.where((section) => section.isParticipantFacing).toList();

  /// True when the form has sections and every required one is reviewed.
  bool get isReadyForParticipants =>
      sections.isNotEmpty &&
      sections
          .where((section) => section.required)
          .every((section) => section.isParticipantFacing);
}
