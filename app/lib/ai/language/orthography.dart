/// The four click letters (U+01C0–U+01C3).
const dentalClick = 'ǀ';
const lateralClick = 'ǁ';
const palatalClick = 'ǂ';
const alveolarClick = 'ǃ';

/// How a language written with click letters is typed and stored.
///
/// The tables come from the language pack `orthography/*.json` files.
final class Orthography {
  const Orthography({
    required this.name,
    required this.alwaysConverted,
    required this.convertedBeforeLetter,
    this.protectedWords = const [],
  });

  final String name;

  /// Stand-ins that are never punctuation, converted wherever they appear.
  final Map<String, String> alwaysConverted;

  /// Stand-ins that are also punctuation, converted only before a letter.
  final Map<String, String> convertedBeforeLetter;

  /// Words kept exactly as written, such as the language's own name.
  final List<String> protectedWords;
}

const _ambiguousClickStandIns = {
  '||': lateralClick,
  '//': lateralClick,
  '#': palatalClick,
  '=': palatalClick,
  '|': dentalClick,
  '/': dentalClick,
  '!': alveolarClick,
};

const khoekhoegowab = Orthography(
  name: 'Khoekhoegowab',
  alwaysConverted: {'‡': palatalClick, '≠': palatalClick},
  convertedBeforeLetter: _ambiguousClickStandIns,
);

const juHoansiName = "Ju/'hoansi";

const juHoansi = Orthography(
  name: juHoansiName,
  alwaysConverted: {'‡': palatalClick, '≠': palatalClick, '’': "'"},
  convertedBeforeLetter: _ambiguousClickStandIns,
  // The team spells the language name in ASCII (decision of 16 Oct).
  protectedWords: [juHoansiName],
);
