import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/prompts/consent_output_parser.dart';
import 'package:consentlink/ai/prompts/section_grammar.dart';
import 'package:consentlink/contracts/models.dart' show Confidence;
import 'package:flutter_test/flutter_test.dart';

// One left-to-right pass: a quote inside a class, or a bracket inside a
// literal, must not start a token.
final _literalOrClass = RegExp(r'"(?:[^"\\]|\\.)*"|\[(?:[^\]\\]|\\.)*\]');
final _repeat = RegExp(r'\{\d+(,\d+)?\}');
final _ruleName = RegExp(r'[a-z_]+');

/// Rule name → body, for a grammar with one rule per line.
Map<String, String> _rules(String grammar) => {
  for (final line in grammar.split('\n'))
    line.split(' ::= ').first: line.split(' ::= ').last,
};

void main() {
  final grammar = sectionGrammar(ConsentElement.risks, 'en');

  test('defines every rule it references, starting from root', () {
    final rules = _rules(grammar);
    expect(rules, contains('root'));
    for (final body in rules.values) {
      final bare = body
          .replaceAll(_literalOrClass, ' ')
          .replaceAll(_repeat, ' ');
      for (final name in _ruleName.allMatches(bare)) {
        expect(rules, contains(name[0]), reason: 'undefined rule ${name[0]}');
      }
    }
  });

  test('forces the element key and the form language', () {
    expect(grammar, contains(r'\"key\":\"risks\"'));
    expect(grammar, contains(r'\"missing\":[\"risks\"]'));
    expect(grammar, contains(r'\"form_language\":\"en\"'));
    expect(grammar, isNot(contains('purpose')));
  });

  test('allows only the contract confidence values', () {
    final body = _rules(grammar)['confidence']!;
    for (final confidence in Confidence.values) {
      expect(body, contains('\\"${confidence.name}\\"'));
    }
  });

  // The two shapes the grammar allows, written by hand: the 5a parser must
  // read them unchanged.
  test('both allowed shapes are read by the output parser', () {
    final found = parseConsentDraft(
      '{"form_language":"en","reading_grade":null,"sections":[{"key":"risks",'
      '"title":"Risks","text":"You may feel tired.","source_pages":[3],'
      '"source_quote":"Risks: tiredness.","changes":[],"confidence":"high"}],'
      '"missing":[]}',
    );
    expect(found.draft.sections.single.element, ConsentElement.risks);
    expect(found.issues, isEmpty);

    final notFound = parseConsentDraft(
      '{"form_language":"en","reading_grade":null,"sections":[],'
      '"missing":["risks"]}',
    );
    expect(notFound.draft.missing, [ConsentElement.risks]);
  });
}
