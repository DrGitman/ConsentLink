// test/contracts_test.dart
// Needs dev_dependency json_schema. Run with: flutter test (from the app/ folder).
import 'dart:convert';
import 'dart:io';
import 'package:json_schema/json_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:consentlink/contracts/form_hash.dart';
import 'package:consentlink/contracts/models.dart';

ConsentSection section({
  String text = 'Hello',
  int order = 0,
  String id = 's1',
}) => ConsentSection(
  id: id,
  studyId: 'study1',
  order: order,
  language: 'en',
  text: text,
  sourcePage: 3,
  sourceQuote: 'quote',
  changes: const ['simplified wording'],
  confidence: Confidence.high,
  requiredElement: 'purpose',
  status: SectionStatus.approved,
  approvedBy: 'u1',
  approvedAt: DateTime.utc(2026, 10, 12),
);

void main() {
  final schema = JsonSchema.create(
    File('../schemas/consent_section.schema.json').readAsStringSync(),
  );

  test('ConsentSection JSON matches the shared schema', () {
    final json = jsonDecode(jsonEncode(section().toJson()));
    expect(schema.validate(json).isValid, isTrue);
  });

  test('ConsentSection survives a JSON round trip', () {
    final back = ConsentSection.fromJson(
      jsonDecode(jsonEncode(section().toJson())) as Map<String, dynamic>,
    );
    expect(back.toJson(), section().toJson());
  });

  test('form hash ignores input order but changes with the text', () {
    final a = section(id: 'a', order: 0);
    final b = section(id: 'b', order: 1, text: 'World');
    expect(computeFormHash([a, b]), computeFormHash([b, a]));
    expect(
      computeFormHash([a, b]),
      isNot(computeFormHash([a, section(id: 'b', order: 1, text: 'World!')])),
    );
  });
}
