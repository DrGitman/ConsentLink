import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'orthography.dart';

/// Replaces ASCII click stand-ins in [text] with click letters, then
/// normalises it to NFC.
///
/// Use it only on text written in the language, never on whole documents:
/// URLs, file paths and `{placeholders}` would be corrupted.
String normaliseLanguageText(String text, Orthography orthography) {
  final always = orthography.alwaysConverted;
  final withoutUnambiguous = always.isEmpty
      ? text
      : text.replaceAllMapped(
          RegExp(_longestFirst(always.keys)),
          (match) => always[match[0]]!,
        );
  if (orthography.convertedBeforeLetter.isEmpty) {
    return unorm.nfc(withoutUnambiguous);
  }
  final withClicks = withoutUnambiguous.replaceAllMapped(
    _beforeLetterPattern(orthography),
    (match) => orthography.convertedBeforeLetter[match[0]]!,
  );
  return unorm.nfc(withClicks);
}

// A click is followed by a letter, or by an apostrophe then a letter.
RegExp _beforeLetterPattern(Orthography orthography) {
  final standIns = _longestFirst(orthography.convertedBeforeLetter.keys);
  return RegExp("(?:$standIns)(?=\\p{L}|'\\p{L})", unicode: true);
}

// Longest first, so '||' is tried before '|'.
String _longestFirst(Iterable<String> keys) =>
    (keys.toList()..sort((a, b) => b.length.compareTo(a.length)))
        .map(RegExp.escape)
        .join('|');
