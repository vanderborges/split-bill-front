import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/widgets/glass.dart';
import 'package:split_bill_front/shared/widgets/glass_dropdown_field.dart';

void main() {
  Widget field({String? initial, ValueChanged<String?>? onChanged}) =>
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Align(
              alignment: Alignment.topCenter,
              child: GlassDropdownField<String?>(
                key: const ValueKey('campo'),
                initialValue: initial,
                decoration: const InputDecoration(labelText: 'Grupo'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (var i = 1; i <= 12; i++)
                    DropdownMenuItem(value: 'g$i', child: Text('Grupo $i')),
                ],
                onChanged: onChanged ?? (_) {},
              ),
            ),
          ),
        ),
      );

  testWidgets('a lista abre logo abaixo do campo', (tester) async {
    await tester.pumpWidget(field(initial: 'g5'));
    final fieldRect = tester.getRect(find.byKey(const ValueKey('campo')));
    await tester.tap(find.byKey(const ValueKey('campo')));
    await tester.pumpAndSettle();
    // Primeiro item do menu aparece abaixo do campo (não por cima dele).
    final firstItem = tester.getRect(find.text('Todos').last);
    expect(firstItem.top, greaterThanOrEqualTo(fieldRect.bottom));
  });

  testWidgets('mostra no máximo 6 itens e meio', (tester) async {
    await tester.pumpWidget(field());
    await tester.tap(find.byKey(const ValueKey('campo')));
    await tester.pumpAndSettle();
    final menu = find.ancestor(
        of: find.text('Grupo 12'),
        matching: find.byType(SingleChildScrollView));
    // Menu rola: altura limitada a 6 itens e meio (+ respiro).
    expect(tester.getSize(menu.first).height,
        lessThanOrEqualTo(glassMenuMaxHeight));
    expect(tester.getSize(menu.first).height, greaterThan(6 * 48));
  });

  testWidgets('escolher troca o valor e avisa', (tester) async {
    String? picked = 'nada';
    await tester.pumpWidget(field(initial: 'g1', onChanged: (v) => picked = v));
    await tester.tap(find.byKey(const ValueKey('campo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grupo 3').last);
    await tester.pumpAndSettle();
    expect(picked, 'g3');
    expect(find.text('Grupo 3'), findsOneWidget);

    // Item de valor null também é uma escolha (não é "fechou o menu").
    await tester.tap(find.byKey(const ValueKey('campo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos').last);
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });
}
