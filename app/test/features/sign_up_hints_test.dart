import 'package:consentlink/features/auth/widgets/sign_up_hints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('institution suggestion requires the exact configured domain', () {
    expect(suggestedInstitution('tester@nust.na'), 'NUST');
    expect(suggestedInstitution(' TESTER@NUST.NA '), 'NUST');

    expect(suggestedInstitution('tester@nust.na.example.com'), isNull);
    expect(suggestedInstitution('tester@notnust.na'), isNull);
    expect(suggestedInstitution('@nust.na'), isNull);
    expect(suggestedInstitution('tester@@nust.na'), isNull);
    expect(suggestedInstitution('tester@example.com'), isNull);
  });

  test('a familiar password is not rated strong', () {
    expect(estimatePasswordScore('password123'), lessThan(3));
  });
}
