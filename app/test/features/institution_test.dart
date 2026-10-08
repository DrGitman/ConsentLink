import 'package:consentlink/features/institution/institution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('institutions can be found by abbreviation or full name', () {
    expect(Institution.nust.matches(' nust '), isTrue);
    expect(Institution.nust.matches('SCIENCE'), isTrue);
    expect(Institution.welwitchia.matches('Welwitchia'), isTrue);
    expect(Institution.unam.matches('management'), isFalse);
  });

  test('an empty search includes every institution', () {
    expect(
      Institution.values.every((institution) => institution.matches('')),
      isTrue,
    );
  });
}
