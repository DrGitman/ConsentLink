// contracts/languages.dart
// The ONE list of languages. Agreed between P1 (UI), P2 (data), P3 (AI).
//
// - `code` is what we store and send everywhere: database, /schemas, language
//   packs, ConsentSection.language, Participant.language, Consent.language.
//   It is a BCP 47 tag: the two-letter ISO 639-1 code when one exists
//   (en, af, de, hz, ng, kj), otherwise ISO 639-3 (naq, ktz, kwn, loz).
// - `displayName` is only for the screen. Never store or compare it.
// - Must match the rows in supabase/migrations (table public.languages).
//   Adding a language = one entry here + one INSERT there.

class ConsentLanguage {
  final String code;
  final String displayName;
  const ConsentLanguage(this.code, this.displayName);
}

const consentLanguages = <ConsentLanguage>[
  ConsentLanguage('en', 'English'),
  ConsentLanguage('af', 'Afrikaans'),
  ConsentLanguage('de', 'Deutsch'),
  ConsentLanguage('hz', 'Otjiherero'),
  ConsentLanguage('naq', 'Khoekhoegowab'),
  // U+01C0 LATIN LETTER DENTAL CLICK, not the ASCII "/" or "|".
  ConsentLanguage('ktz', 'Juǀ\'hoansi'),
  ConsentLanguage('kwn', 'Rukwangali'),
  ConsentLanguage('loz', 'Silozi'),
  // "Oshiwambo" is two written standards; a form is in one or the other.
  ConsentLanguage('ng', 'Oshindonga'),
  ConsentLanguage('kj', 'Oshikwanyama'),
];

/// The language for [code], or null if we don't support it.
ConsentLanguage? languageByCode(String code) {
  for (final l in consentLanguages) {
    if (l.code == code) return l;
  }
  return null;
}

/// Display name for [code]; falls back to the code itself.
String languageName(String code) => languageByCode(code)?.displayName ?? code;
