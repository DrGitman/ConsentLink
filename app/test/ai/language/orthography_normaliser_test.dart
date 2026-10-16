import 'package:consentlink/ai/language/orthography.dart';
import 'package:consentlink/ai/language/orthography_normaliser.dart';
import 'package:flutter_test/flutter_test.dart';

// Invented strings typed with ASCII stand-ins, not real participant text.
void main() {
  group('converts stand-ins before a letter', () {
    final cases = {
      '!ha': '${alveolarClick}ha',
      '||kho': '${lateralClick}kho',
      '//kho': '${lateralClick}kho',
      '|oa': '${dentalClick}oa',
      '/oa': '${dentalClick}oa',
      '#xa': '${palatalClick}xa',
      '=xa': '${palatalClick}xa',
      'g!a': 'g${alveolarClick}a',
    };
    cases.forEach((typed, expected) {
      test('"$typed"', () {
        expect(normaliseLanguageText(typed, khoekhoegowab), expected);
      });
    });
  });

  test('always converts the dagger and not-equal signs', () {
    expect(
      normaliseLanguageText('‡ ≠', khoekhoegowab),
      '$palatalClick $palatalClick',
    );
  });

  test('converts a glottalised click before an apostrophe', () {
    expect(normaliseLanguageText("!'han", juHoansi), "$alveolarClick'han");
  });

  test('keeps punctuation that is not before a letter', () {
    const text = 'Hello! Is 5 = 5? Yes / no. A | b.';

    expect(normaliseLanguageText(text, khoekhoegowab), text);
  });

  test('keeps the Ju/\'hoansi name in ASCII', () {
    expect(
      normaliseLanguageText("We speak Ju/'hoansi and !ha.", juHoansi),
      "We speak Ju/'hoansi and ${alveolarClick}ha.",
    );
  });

  test('replaces the curly apostrophe in Ju/\'hoansi', () {
    expect(normaliseLanguageText('!’han', juHoansi), "$alveolarClick'han");
  });

  test('keeps click letters already in Unicode', () {
    const text = '$dentalClick$lateralClick$palatalClick${alveolarClick}a';

    expect(normaliseLanguageText(text, juHoansi), text);
  });

  test('composes tone marks to NFC', () {
    const decomposed = 'Jù mí â ā';

    expect(normaliseLanguageText(decomposed, juHoansi), 'Jù mí â ā');
  });

  test('handles empty text and empty tables', () {
    const plain = Orthography(
      name: 'Plain',
      alwaysConverted: {},
      convertedBeforeLetter: {},
    );

    expect(normaliseLanguageText('', juHoansi), '');
    expect(normaliseLanguageText('!ha', plain), '!ha');
  });
}
