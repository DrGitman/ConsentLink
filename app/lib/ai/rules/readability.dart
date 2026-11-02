import '../domain/generated_section.dart';

/// The only language the syllable counter understands (decision D3.2).
const readabilityLanguage = 'en';

/// Below this, a Flesch-Kincaid grade is too noisy to show.
const minWordsForGrade = 20;

// Flesch-Kincaid Grade Level coefficients.
const _wordsPerSentenceWeight = 0.39;
const _syllablesPerWordWeight = 11.8;
const _gradeOffset = 15.59;

final _wordPattern = RegExp(r"[\p{L}]+(?:['’][\p{L}]+)*", unicode: true);
final _sentenceEndPattern = RegExp(r'[.!?]+');
final _vowelGroupPattern = RegExp('[aeiouy]+');
final _silentEndingPattern = RegExp(r'[^aeiouy](e|ed|es)$');
final _soundedEndingPattern = RegExp(
  r'([^aeiouy]le|[td]ed|([sxz]|[cs]h|[cg])es)$',
);

/// School grade needed to read [text] (Flesch-Kincaid), never below 0.
///
/// Null when it is not measured: [languageCode] is not English, or [text]
/// has fewer than [minWordsForGrade] words.
double? readingGradeOf(String text, String languageCode) {
  if (languageCode.split('-').first.toLowerCase() != readabilityLanguage) {
    return null;
  }
  final words = _wordPattern
      .allMatches(text)
      .map((match) => match.group(0)!.toLowerCase())
      .toList();
  if (words.length < minWordsForGrade) return null;

  // Text without a sentence end counts as one sentence.
  final sentences = _sentenceEndPattern.allMatches(text).length;
  final syllables = words.map(syllablesIn).fold(0, (sum, n) => sum + n);
  final wordsPerSentence = words.length / (sentences == 0 ? 1 : sentences);
  final syllablesPerWord = syllables / words.length;
  final grade =
      _wordsPerSentenceWeight * wordsPerSentence +
      _syllablesPerWordWeight * syllablesPerWord -
      _gradeOffset;
  return grade < 0 ? 0 : grade;
}

/// Reading grade of the whole form: the section texts read in order.
double? draftReadingGrade(List<GeneratedSection> sections, String language) =>
    readingGradeOf(
      sections.map((section) => section.text).join('\n'),
      language,
    );

/// Heuristic English syllable count of one lower-case [word], at least 1.
int syllablesIn(String word) {
  var count = _vowelGroupPattern.allMatches(word).length;
  // "make", "asked", "makes" lose a vowel group; "simple", "wanted" do not.
  if (count > 1 &&
      _silentEndingPattern.hasMatch(word) &&
      !_soundedEndingPattern.hasMatch(word)) {
    count--;
  }
  return count < 1 ? 1 : count;
}
