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

  testWidgets('abre com mais itens, até antes do limite de baixo, e rola',
      (tester) async {
    await tester.pumpWidget(field());
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tap(find.byKey(const ValueKey('campo')));
    await tester.pumpAndSettle();
    final menu = find
        .ancestor(
            of: find.text('Grupo 1').last,
            matching: find.byType(SingleChildScrollView))
        .first;
    final rect = tester.getRect(menu);
    // Mais que os 6 itens e meio de antes, sem passar do fim da tela.
    expect(rect.height, greaterThan(glassMenuMaxHeight));
    expect(rect.bottom, lessThanOrEqualTo(screen.height));
    // Não cabem os 13: o último fica pra rolar.
    expect(tester.getRect(find.text('Grupo 12').last).top,
        greaterThan(rect.bottom - 1));
  });

  testWidgets('campo perto do fim: a lista não passa do limite de baixo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Spacer(),
            GlassDropdownField<String>(
              key: const ValueKey('baixo'),
              initialValue: 'a',
              items: [
                for (final v in ['a', 'b', 'c', 'd', 'e'])
                  DropdownMenuItem(value: v, child: Text('Item $v')),
              ],
              onChanged: (_) {},
            ),
            const SizedBox(height: 150),
          ],
        ),
      ),
    ));
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tap(find.byKey(const ValueKey('baixo')));
    await tester.pumpAndSettle();
    // Abre pra cima (embaixo não cabe) e nada passa do fim da tela.
    final lastItem = tester.getRect(find.text('Item e').last);
    final field = tester.getRect(find.byKey(const ValueKey('baixo')));
    expect(lastItem.bottom, lessThanOrEqualTo(screen.height));
    expect(lastItem.bottom, lessThanOrEqualTo(field.top));
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
