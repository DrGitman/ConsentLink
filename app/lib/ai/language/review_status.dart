/// How far a translated text has been checked, lowest first.
enum ReviewStatus {
  machineDraft('machine_draft'),
  needsReview('needs_review'),
  reviewed('reviewed'),
  verifiedOfficial('verified_official');

  const ReviewStatus(this.jsonValue);

  final String jsonValue;

  /// Only reviewed text, or better, may be shown to a participant.
  bool get isParticipantFacing => index >= reviewed.index;
}

/// How well a reviewer speaks the language they check.
enum ReviewerFluency {
  firstLanguage('first_language'),
  fluent('fluent'),
  learner('learner');

  const ReviewerFluency(this.jsonValue);

  final String jsonValue;

  bool get canApprove => this != learner;
}

/// The person who checked a translated text.
final class Reviewer {
  /// Throws an [ArgumentError] when [name] is blank.
  Reviewer({required this.name, required this.fluency, required this.date}) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Is blank');
    }
  }

  final String name;
  final ReviewerFluency fluency;
  final DateTime date;
}
