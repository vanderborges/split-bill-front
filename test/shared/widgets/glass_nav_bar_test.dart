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
        .widget<Transform>(find.byKey(const ValueKey('nav-pill')))
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
    expect(find.byKey(const ValueKey('nav-pill')), findsNothing);
    expect(labelColor(tester, 'Extrato'), isNot(const Color(0xFF0C66E4)));
  });

  testWidgets('item selecionado infla ao trocar de aba', (tester) async {
    await tester.pumpWidget(bar(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(bar(2));
    double scaleOf(String label) => tester
        .widget<Transform>(find
            .ancestor(of: find.text(label), matching: find.byType(Transform))
            .first)
        .transform
        .getMaxScaleOnAxis();
    expect(scaleOf('Eventos'), closeTo(1, 0.01));
    await tester.pumpAndSettle();
    expect(scaleOf('Eventos'), closeTo(1.08, 0.01));
    expect(scaleOf('Início'), closeTo(1, 0.01));
  });

  testWidgets('compacta: some o nome e a barra fica menor; volta ao normal',
      (tester) async {
    Widget compactBar(bool compact) => MaterialApp(
          home: Scaffold(
            bottomNavigationBar: GlassNavBar(
              items: items,
              selectedIndex: 0,
              compact: compact,
              onSelected: (_) {},
            ),
          ),
        );
    double barHeight() => tester.getSize(find.byType(GlassSurface)).height;
    double labelOpacity() => tester
        .widget<Opacity>(find
            .ancestor(of: find.text('Grupos'), matching: find.byType(Opacity))
            .first)
        .opacity;

    await tester.pumpWidget(compactBar(false));
    await tester.pumpAndSettle();
    final normal = barHeight();
    expect(labelOpacity(), 1);

    await tester.pumpWidget(compactBar(true));
    await tester.pumpAndSettle();
    expect(barHeight(), lessThan(normal));
    expect(labelOpacity(), 0);

    await tester.pumpWidget(compactBar(false));
    await tester.pumpAndSettle();
    expect(barHeight(), normal);
    expect(labelOpacity(), 1);
  });

  testWidgets('toque avisa o índice da aba', (tester) async {
    int? tapped;
    await tester.pumpWidget(bar(0, onSelected: (index) => tapped = index));
    await tester.tap(find.text('Eventos'));
    expect(tapped, 2);
  });
}
