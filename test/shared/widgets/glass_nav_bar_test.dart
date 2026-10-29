import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/widgets/glass.dart';

void main() {
  const items = [
    GlassNavItem(
        icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Início'),
    GlassNavItem(
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: 'Grupos'),
    GlassNavItem(
        icon: Icons.event_outlined,
        selectedIcon: Icons.event,
        label: 'Eventos'),
    GlassNavItem(
        icon: Icons.list_alt_outlined,
        selectedIcon: Icons.list_alt,
        label: 'Extrato'),
  ];

  Widget bar(int selected, {ValueChanged<int>? onSelected}) => MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GlassNavBar(
            items: items,
            selectedIndex: selected,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      );

  Color? labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  testWidgets('selecionado fica azul (Trello) e os outros não', (tester) async {
    await tester.pumpWidget(bar(1));
    expect(labelColor(tester, 'Grupos'), const Color(0xFF0C66E4));
    expect(labelColor(tester, 'Início'), isNot(const Color(0xFF0C66E4)));
    expect(find.byIcon(Icons.groups), findsOneWidget);
  });

  testWidgets('a pílula desliza da aba anterior até a nova', (tester) async {
    await tester.pumpWidget(bar(0));
    await tester.pumpAndSettle();
    // Tela nova monta outra barra (sem shell): parte da posição anterior.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(bar(3));
    double offset() => tester
        .widget<Transform>(find.descendant(
            of: find.byType(GlassNavBar), matching: find.byType(Transform)))
        .transform
        .getTranslation()
        .x;
    final start = offset();
    await tester.pump(const Duration(milliseconds: 100));
    final middle = offset();
    await tester.pumpAndSettle();
    final end = offset();
    expect(start, 0);
    expect(middle, greaterThan(start));
    expect(end, greaterThan(middle));
  });

  testWidgets('sem aba selecionada não mostra a pílula', (tester) async {
    await tester.pumpWidget(bar(-1));
    expect(
        find.descendant(
            of: find.byType(GlassNavBar), matching: find.byType(Transform)),
        findsNothing);
    expect(labelColor(tester, 'Extrato'), isNot(const Color(0xFF0C66E4)));
  });

  testWidgets('toque avisa o índice da aba', (tester) async {
    int? tapped;
    await tester.pumpWidget(bar(0, onSelected: (index) => tapped = index));
    await tester.tap(find.text('Eventos'));
    expect(tapped, 2);
  });
}
