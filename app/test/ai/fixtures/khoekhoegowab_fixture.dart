import 'package:consentlink/ai/language/orthography.dart';

// Invented strings, not real participant text (task K). Each one holds the
// four click letters, so a test can check they come out unchanged.

/// Language code of Khoekhoegowab in the app (`contracts/languages.dart`).
const khoekhoegowabCode = 'naq';

const allClickLetters = [
  dentalClick,
  lateralClick,
  palatalClick,
  alveolarClick,
];

/// A made-up sentence in the shape of Khoekhoegowab text.
const khoekhoegowabSentence =
    'Sa ${dentalClick}gôa ${lateralClick}gâi ${palatalClick}khanis '
    '${alveolarClick}nâ-e ra ${dentalClick}khî.';

/// A made-up researcher name with a click letter, for English text.
const clickResearcherName = 'Dr ${palatalClick}Garoes';
