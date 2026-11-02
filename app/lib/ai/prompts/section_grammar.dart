import '../domain/consent_element.dart';

/// GBNF grammar for one model answer: a `/schemas` consent draft holding
/// either the section of [element] or [element] in `missing` (D5.6).
///
/// The JSON is compact, so no token is spent on whitespace. `reading_grade`
/// is null: the service measures it (decision D3.2).
String sectionGrammar(ConsentElement element, String formLanguage) {
  final key = element.jsonKey;
  return [
    'root ::= ${_literal('{"form_language":"$formLanguage",'
    '"reading_grade":null,')} (found | notfound) ${_literal('}')}',
    'found ::= ${_literal('"sections":[')} section '
        '${_literal('],"missing":[]')}',
    'notfound ::= ${_literal('"sections":[],"missing":["$key"]')}',
    'section ::= ${_literal('{"key":"$key","title":')} string '
        '${_literal(',"text":')} string '
        '${_literal(',"source_pages":')} pages '
        '${_literal(',"source_quote":')} string '
        '${_literal(',"changes":')} strings '
        '${_literal(',"confidence":')} confidence ${_literal('}')}',
    'pages ::= "[" page ("," page)* "]"',
    'page ::= [1-9] [0-9]{0,3}',
    'strings ::= "[" (string ("," string)*)? "]"',
    r'confidence ::= "\"low\"" | "\"medium\"" | "\"high\""',
    r'string ::= "\"" char* "\""',
    r'char ::= [^"\\\x00-\x1F] | "\\" (["\\/bfnrt] | "u" [0-9a-fA-F]{4})',
  ].join('\n');
}

/// A GBNF literal matching [text] exactly.
String _literal(String text) =>
    '"${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
