import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/core/theme/app_theme.dart';
import 'package:split_bill_front/shared/widgets/money_text.dart';

void main() {
  group('formatCurrencyBRL', () {
    test('adds thousands separator and two decimal digits', () {
      expect(formatCurrencyBRL(1280), 'R\$ 1.280,00');
    });

    test('formats cents from the domain-rules.md rounding example', () {
      expect(formatCurrencyBRL(33.33), 'R\$ 33,33');
      expect(formatCurrencyBRL(33.34), 'R\$ 33,34');
    });

    test('negative values are prefixed with a minus sign', () {
      expect(formatCurrencyBRL(-42.5), '-R\$ 42,50');
    });

    test('showSign adds a plus sign for positive values', () {
      expect(formatCurrencyBRL(37.5, showSign: true), '+R\$ 37,50');
      expect(formatCurrencyBRL(-37.5, showSign: true), '-R\$ 37,50');
      expect(formatCurrencyBRL(0, showSign: true), 'R\$ 0,00');
    });
  });

  testWidgets('MoneyText colors by sign using semantic tokens',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Column(
            children: [
              MoneyText(150.0, colorBySign: true),
              MoneyText(-90.0, colorBySign: true),
            ],
          ),
        ),
      ),
    );

    final positiveText = tester.widget<Text>(find.text('R\$ 150,00'));
    final negativeText = tester.widget<Text>(find.text('-R\$ 90,00'));

    expect(positiveText.data, 'R\$ 150,00');
    expect(negativeText.data, '-R\$ 90,00');
    expect(positiveText.style?.color, isNot(equals(negativeText.style?.color)));
  });
}
