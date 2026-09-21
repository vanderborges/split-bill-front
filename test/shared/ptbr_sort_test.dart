import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/ptbr_sort.dart';

void main() {
  group('compareNamesPtBr', () {
    test('is case-insensitive', () {
      expect(compareNamesPtBr('ana', 'Ana'), 0);
    });

    test('ignores common Portuguese diacritics', () {
      expect(compareNamesPtBr('Águeda', 'Agueda'), 0);
    });

    test('orders accented names by their base letter, not code point', () {
      // A plain String.compareTo would put "Águeda" after "Zeca" because
      // 'á' (U+00E1) sits after 'z' (U+007A) in UTF-16.
      final names = ['Zeca', 'Águeda', 'Bruno']..sort(compareNamesPtBr);
      expect(names, ['Águeda', 'Bruno', 'Zeca']);
    });
  });

  group('sortedByNamePtBr', () {
    test('sorts a list of objects by the extracted name', () {
      final people = ['Pedro', 'ana', 'João', 'Célia'];
      expect(
        sortedByNamePtBr(people, (name) => name),
        ['ana', 'Célia', 'João', 'Pedro'],
      );
    });

    test('does not mutate the original list', () {
      final people = ['Pedro', 'Ana'];
      final sorted = sortedByNamePtBr(people, (name) => name);
      expect(people, ['Pedro', 'Ana']);
      expect(sorted, ['Ana', 'Pedro']);
    });
  });
}
