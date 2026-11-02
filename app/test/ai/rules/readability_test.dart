import 'package:consentlink/ai/drafting/fake_sample_draft.dart';
import 'package:consentlink/ai/rules/readability.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/khoekhoegowab_fixture.dart';

// Invented plain-language text: 2 sentences of 10 one-syllable words.
const _simpleText =
    'You can stop now and we will not be sad. '
    'We keep your name safe and we do not tell.';

void main() {
  group('syllablesIn', () {
    const expected = {
      'the': 1,
      'make': 1,
      'asked': 1,
      'makes': 1,
      'water': 2,
      'simple': 2,
      'people': 2,
      'wanted': 2,
      'boxes': 2,
      'study': 2,
      'questionnaire': 3,
      'university': 5,
      'hmm': 1,
    };
    for (final MapEntry(key: word, value: syllables) in expected.entries) {
      test('"$word" has $syllables', () {
        expect(syllablesIn(word), syllables);
      });
    }
  });

  group('readingGradeOf', () {
    test('follows the Flesch-Kincaid formula', () {
      // 0.39 × 20/2 + 11.8 × 20/20 − 15.59
      expect(readingGradeOf(_simpleText, 'en'), closeTo(0.11, 0.001));
    });

    test('longer words and sentences give a higher grade', () {
      const harder =
          'Participation in this investigation involves completing '
          'questionnaires regarding household water accessibility, '
          'sanitation infrastructure and community governance arrangements '
          'administered by trained research personnel.';
      expect(readingGradeOf(harder, 'en'), greaterThan(12));
    });

    test('is never below 0', () {
      const tiny =
          'Yes. No. Yes. No. Yes. No. Yes. No. Yes. No. '
          'Yes. No. Yes. No. Yes. No. Yes. No. Yes. No.';
      expect(readingGradeOf(tiny, 'en'), 0);
    });

    test('text without a full stop counts as one sentence', () {
      expect(
        readingGradeOf(_simpleText.replaceAll('.', ''), 'en'),
        greaterThan(readingGradeOf(_simpleText, 'en')!),
      );
    });

    test('accepts a regional English tag', () {
      expect(readingGradeOf(_simpleText, 'en-NA'), isNotNull);
    });

    test('is not measured below $minWordsForGrade words', () {
      expect(readingGradeOf('You can stop at any time.', 'en'), isNull);
    });

    test('is not measured in other languages, even with clicks', () {
      final longText = List.filled(5, khoekhoegowabSentence).join(' ');
      expect(readingGradeOf(longText, khoekhoegowabCode), isNull);
    });
  });

  test('draftReadingGrade reads the sections in order', () {
    final grade = draftReadingGrade(fakeSampleSections, fakeFormLanguage);
    final joined = fakeSampleSections.map((section) => section.text).join('\n');
    expect(grade, readingGradeOf(joined, fakeFormLanguage));
    expect(grade, lessThan(8));
  });
}
