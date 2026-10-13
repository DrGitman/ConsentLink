import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/domain/generated_section.dart';
import 'package:consentlink/contracts/models.dart' show Confidence;
import 'package:flutter_test/flutter_test.dart';

// Invented test data; not from a real proposal.
GeneratedSection _section({
  String title = 'Risks & discomforts',
  String text = 'You may feel tired. You can rest or stop at any time.',
  List<int> sourcePages = const [6],
  String? sourceQuote = 'Participants may experience mild fatigue.',
  List<String> changes = const ['Replaced jargon'],
  SectionSource source = SectionSource.proposal,
}) => GeneratedSection(
  element: ConsentElement.risks,
  title: title,
  text: text,
  sourcePages: sourcePages,
  sourceQuote: sourceQuote,
  changes: changes,
  confidence: Confidence.high,
  source: source,
);

void main() {
  group('valid section', () {
    test('keeps its fields', () {
      final section = _section(sourcePages: [6, 7]);

      expect(section.element, ConsentElement.risks);
      expect(section.sourcePages, [6, 7]);
      expect(section.changes, ['Replaced jargon']);
      expect(section.confidence, Confidence.high);
    });

    test('comes from the proposal by default', () {
      final section = GeneratedSection(
        element: ConsentElement.purpose,
        title: 'Purpose',
        text: 'We want to learn how families get clean water.',
        sourcePages: const [1],
        changes: const [],
        confidence: Confidence.medium,
      );

      expect(section.source, SectionSource.proposal);
      expect(section.sourceQuote, isNull);
    });

    test('from a template may have no source pages', () {
      final section = _section(
        sourcePages: const [],
        source: SectionSource.template,
      );

      expect(section.sourcePages, isEmpty);
    });
  });

  group('rejects', () {
    final invalidCases = <String, GeneratedSection Function()>{
      'a blank title': () => _section(title: '  '),
      'a blank text': () => _section(text: ''),
      'a blank source quote': () => _section(sourceQuote: ' '),
      'a blank change': () => _section(changes: ['Replaced jargon', '']),
      'page 0': () => _section(sourcePages: [0]),
      'duplicate pages': () => _section(sourcePages: [6, 6]),
      'no pages for a proposal section': () => _section(sourcePages: []),
    };

    invalidCases.forEach((name, build) {
      test(name, () => expect(build, throwsArgumentError));
    });
  });

  group('lists', () {
    test('are copied, so the input can change safely', () {
      final pages = [6];
      final changes = ['Replaced jargon'];
      final section = _section(sourcePages: pages, changes: changes);

      pages.add(7);
      changes.add('Added no penalty');

      expect(section.sourcePages, [6]);
      expect(section.changes, ['Replaced jargon']);
    });

    test('cannot be modified', () {
      final section = _section();

      expect(() => section.sourcePages.add(7), throwsUnsupportedError);
      expect(() => section.changes.add('x'), throwsUnsupportedError);
    });
  });

  group('equality', () {
    test('holds for sections with the same values', () {
      expect(_section(), _section());
      expect(_section().hashCode, _section().hashCode);
    });

    test('fails when a list differs', () {
      expect(_section(), isNot(_section(sourcePages: [6, 7])));
      expect(_section(), isNot(_section(changes: [])));
    });
  });
}
