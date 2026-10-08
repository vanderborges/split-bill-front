import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/widgets/amount_field.dart';

void main() {
  group('parseAmountFieldText', () {
    test('parses a formatted BRL string back into a double', () {
      expect(parseAmountFieldText('196,40'), 196.40);
      expect(parseAmountFieldText('1.280,50'), 1280.50);
    });

    test('returns null for empty input', () {
      expect(parseAmountFieldText(''), isNull);
    });
  });

  testWidgets('typing digits masks live like a calculator field',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AmountField(controller: controller),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '19640');
    await tester.pump();

    expect(controller.text, '196,40');
    expect(parseAmountFieldText(controller.text), 196.40);
  });

  group('calculadora na barra do teclado', () {
    Future<TextEditingController> pumpField(WidgetTester tester) async {
      // Simula teclado virtual aberto — a barra só aparece com viewInsets.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AmountField(controller: controller)),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      return controller;
    }

    testWidgets('soma dois valores em reais', (tester) async {
      final controller = await pumpField(tester);
      await tester.enterText(find.byType(TextField), '5000');
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(controller.text, '');
      await tester.enterText(find.byType(TextField), '2550');
      await tester.tap(find.text('='));
      await tester.pump();
      expect(parseAmountFieldText(controller.text), 75.50);
    });

    testWidgets('divide pelo número digitado sem máscara', (tester) async {
      final controller = await pumpField(tester);
      await tester.enterText(find.byType(TextField), '12000');
      await tester.tap(find.text('÷'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '3');
      await tester.pump();
      expect(controller.text, '3');
      await tester.tap(find.text('='));
      await tester.pump();
      expect(parseAmountFieldText(controller.text), 40.00);
    });

    testWidgets('OK resolve a conta pendente', (tester) async {
      final controller = await pumpField(tester);
      await tester.enterText(find.byType(TextField), '10000');
      await tester.tap(find.text('−'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '3000');
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(parseAmountFieldText(controller.text), 70.00);
    });
  });
}
