import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/language/review_status.dart';
import 'package:consentlink/ai/language/translated_form.dart';
import 'package:flutter_test/flutter_test.dart';

// Invented test data; not from a real pack or reviewer.
Reviewer _reviewer(ReviewerFluency fluency) =>
    Reviewer(name: 'Test Reviewer', fluency: fluency, date: DateTime(2026));

TranslatedSection _section({
  String key = 'purpose',
  bool required = true,
  ReviewStatus status = ReviewStatus.machineDraft,
  Reviewer? reviewer,
}) => TranslatedSection(
  key: key,
  element: ConsentElement.purpose,
  title: 'Title',
  text: 'Translated text.',
  required: required,
  status: status,
  reviewer: reviewer,
);

TranslatedForm _form(List<TranslatedSection> sections) => TranslatedForm(
  id: 'consent-master-v1',
  languageCode: 'ktz',
  version: '0.1.0',
  sections: sections,
);

void main() {
  test('only reviewed or better is participant-facing', () {
    expect(ReviewStatus.values.where((status) => status.isParticipantFacing), [
      ReviewStatus.reviewed,
      ReviewStatus.verifiedOfficial,
    ]);
  });

  test('learners cannot approve', () {
    expect(ReviewerFluency.values.where((fluency) => fluency.canApprove), [
      ReviewerFluency.firstLanguage,
      ReviewerFluency.fluent,
    ]);
  });

  group('TranslatedSection', () {
    test('markReviewed keeps the text and sets the reviewer', () {
      final reviewer = _reviewer(ReviewerFluency.fluent);
      final section = _section().markReviewed(reviewer);

      expect(section.status, ReviewStatus.reviewed);
      expect(section.reviewer, same(reviewer));
      expect(section.text, 'Translated text.');
      expect(section.isParticipantFacing, isTrue);
    });

    test('markReviewed rejects a learner', () {
      expect(
        () => _section().markReviewed(_reviewer(ReviewerFluency.learner)),
        throwsArgumentError,
      );
    });

    test('rejects reviewed without a reviewer', () {
      expect(
        () => _section(status: ReviewStatus.reviewed),
        throwsArgumentError,
      );
    });

    test('verified official needs no reviewer', () {
      expect(
        _section(status: ReviewStatus.verifiedOfficial).isParticipantFacing,
        isTrue,
      );
    });

    test('rejects a blank key', () {
      expect(() => _section(key: ' '), throwsArgumentError);
    });

    test('rejects a blank reviewer name', () {
      expect(
        () => Reviewer(
          name: '',
          fluency: ReviewerFluency.fluent,
          date: DateTime(2026),
        ),
        throwsArgumentError,
      );
    });
  });

  group('TranslatedForm', () {
    final reviewed = _section(
      key: 'risks',
      status: ReviewStatus.reviewed,
      reviewer: _reviewer(ReviewerFluency.firstLanguage),
    );

    test('shows only participant-facing sections', () {
      final form = _form([_section(), reviewed]);

      expect(form.participantSections, [reviewed]);
      expect(form.isReadyForParticipants, isFalse);
    });

    test('is ready when every required section is reviewed', () {
      final optionalDraft = _section(key: 'extra', required: false);

      expect(_form([reviewed, optionalDraft]).isReadyForParticipants, isTrue);
    });

    test('is not ready without sections', () {
      expect(_form(const []).isReadyForParticipants, isFalse);
    });

    test('rejects two sections with the same key', () {
      expect(() => _form([_section(), _section()]), throwsArgumentError);
    });
  });
}
