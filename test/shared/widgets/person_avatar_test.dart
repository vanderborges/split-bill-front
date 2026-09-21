import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/widgets/person_avatar.dart';

void main() {
  group('initialsFor', () {
    test('single name returns one letter', () {
      expect(initialsFor('João'), 'J');
    });

    test('full name returns first and last initials', () {
      expect(initialsFor('Maria Silva'), 'MS');
    });

    test('collapses extra whitespace', () {
      expect(initialsFor('  Pedro   Souza  '), 'PS');
    });

    test('empty name returns a placeholder', () {
      expect(initialsFor(''), '?');
    });
  });
}
