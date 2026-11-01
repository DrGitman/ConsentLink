// contracts/languages.dart
// The ONE list of languages. Agreed between P1 (UI), P2 (data), P3 (AI).
//
// - `code` is what we store and send everywhere: database, /schemas,
//   ConsentSection.language, Participant.language, Consent.language.
//   It is a BCP 47 tag: the two-letter ISO 639-1 code when one exists
//   (en, af, de, hz, ng, kj), otherwise ISO 639-3 (naq, ktz, kwn, loz).
// - `iso6393` is the ISO 639-3 code that language pack files use (their
//   "iso639_3" field). Packs keep it; convert with languageByIso6393.
// - `displayName` is only for the screen. Never store or compare it.
// - Must match the rows in supabase/migrations (table public.languages).
//   Adding a language = one entry here + one INSERT there.

class ConsentLanguage {
  final String code;
  final String iso6393;
  final String displayName;
  const ConsentLanguage(this.code, this.iso6393, this.displayName);
}

const consentLanguages = <ConsentLanguage>[
  ConsentLanguage('en', 'eng', 'English'),
  ConsentLanguage('af', 'afr', 'Afrikaans'),
  ConsentLanguage('de', 'deu', 'Deutsch'),
  ConsentLanguage('hz', 'her', 'Otjiherero'),
  ConsentLanguage('naq', 'naq', 'Khoekhoegowab'),
  // U+01C0 LATIN LETTER DENTAL CLICK, not the ASCII "/" or "|".
  ConsentLanguage('ktz', 'ktz', 'Juǀ\'hoansi'),
  ConsentLanguage('kwn', 'kwn', 'Rukwangali'),
  ConsentLanguage('loz', 'loz', 'Silozi'),
  // "Oshiwambo" is two written standards; a form is in one or the other.
  ConsentLanguage('ng', 'ndo', 'Oshindonga'),
  ConsentLanguage('kj', 'kua', 'Oshikwanyama'),
];

/// The language for [code], or null if we don't support it.
ConsentLanguage? languageByCode(String code) {
  for (final l in consentLanguages) {
    if (l.code == code) return l;
  }
  return null;
}

/// The language a pack file's "iso639_3" value refers to, or null.
ConsentLanguage? languageByIso6393(String iso) {
  for (final l in consentLanguages) {
    if (l.iso6393 == iso) return l;
  }
  return null;
}

/// Display name for [code]; falls back to the code itself.
String languageName(String code) => languageByCode(code)?.displayName ?? code;
