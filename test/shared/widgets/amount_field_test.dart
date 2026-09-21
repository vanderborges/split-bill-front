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
}
