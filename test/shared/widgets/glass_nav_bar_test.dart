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

  testWidgets('monocromático (Threads): selecionado com ícone preenchido',
      (tester) async {
    await tester.pumpWidget(bar(1));
    // Modo dia: tudo preto; o selecionado se distingue pelo ícone cheio.
    expect(labelColor(tester, 'Grupos'), Colors.black);
    expect(labelColor(tester, 'Início'), Colors.black);
    expect(find.byIcon(Icons.groups), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
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
    expect(find.byIcon(Icons.list_alt_outlined), findsOneWidget);
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

  testWidgets('arrastar o dedo pela barra abre o item mais próximo',
      (tester) async {
    int? picked;
    await tester.pumpWidget(bar(0, onSelected: (index) => picked = index));
    await tester.pumpAndSettle();
    final start = tester.getCenter(find.text('Início'));
    final end = tester.getCenter(find.text('Eventos'));
    await tester.dragFrom(start, end - start + const Offset(8, 0));
    await tester.pumpAndSettle();
    expect(picked, 2);
  });

  testWidgets('a pílula estica no caminho (gota) e volta ao tamanho',
      (tester) async {
    await tester.pumpWidget(bar(0));
    await tester.pumpAndSettle();
    double pillWidth() => tester
        .getSize(find
            .descendant(
                of: find.byKey(const ValueKey('nav-pill')),
                matching: find.byType(Container))
            .first)
        .width;
    final rest = pillWidth();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(bar(3));
    await tester.pump(const Duration(milliseconds: 80));
    expect(pillWidth(), greaterThan(rest));
    await tester.pumpAndSettle();
    expect(pillWidth(), closeTo(rest, 0.01));
  });
}
