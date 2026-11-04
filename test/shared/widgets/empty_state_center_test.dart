import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/widgets/empty_state.dart';

void main() {
  testWidgets('fica no centro da tela mesmo com filtro em cima',
      (tester) async {
    final bodyKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScreenBodyScope(
          bodyKey: bodyKey,
          child: KeyedSubtree(
            key: bodyKey,
            child: const Column(
              children: [
                SizedBox(height: 200, child: Text('filtros')),
                Expanded(child: EmptyState(message: 'Nada aqui.')),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final screen = tester.getRect(find.byKey(bodyKey));
    final message = tester.getCenter(find.text('Nada aqui.'));
    final icon = tester.getCenter(find.byIcon(Icons.inbox_outlined));
    final blockCenter = (icon.dy + message.dy) / 2;
    expect(blockCenter, closeTo(screen.center.dy, 30));
  });

  testWidgets('botão abaixo do texto continua clicável depois de centralizar',
      (tester) async {
    final bodyKey = GlobalKey();
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScreenBodyScope(
          bodyKey: bodyKey,
          child: KeyedSubtree(
            key: bodyKey,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 250)),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    message: 'Nada aqui.',
                    actionLabel: 'Novo evento',
                    onAction: () => tapped++,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final message = tester.getCenter(find.text('Nada aqui.'));
    final button = tester.getCenter(find.text('Novo evento'));
    expect(button.dy, greaterThan(message.dy));
    await tester.tap(find.text('Novo evento'));
    expect(tapped, 1);
  });

  // Tela de celular com menu embaixo e [preceding] de filtros acima da
  // mensagem (como Despesas: barra + painel fixo + "só minhas despesas").
  Future<GlobalKey> pumpPhone(
    WidgetTester tester, {
    required double preceding,
    required VoidCallback onAction,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bodyKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            size: size, padding: const EdgeInsets.only(bottom: 100)),
        child: Scaffold(
          body: ScreenBodyScope(
            bodyKey: bodyKey,
            child: KeyedSubtree(
              key: bodyKey,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: preceding)),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: 'Nenhuma despesa cadastrada.',
                      message: 'Registre o primeiro gasto deste evento.',
                      actionLabel: 'Nova despesa',
                      onAction: onAction,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return bodyKey;
  }

  testWidgets('botão recebe o toque em toda a área, com muito filtro em cima',
      (tester) async {
    var tapped = 0;
    await pumpPhone(tester, preceding: 340, onAction: () => tapped++);
    final button = tester.getRect(find.byType(FilledButton));
    for (final point in [
      button.topCenter + const Offset(0, 3),
      button.center,
      button.bottomCenter - const Offset(0, 3),
    ]) {
      final before = tapped;
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tapped, before + 1, reason: 'toque em $point, botão em $button');
    }
  });

  testWidgets('tela baixa: o bloco não sobe para cima dos filtros',
      (tester) async {
    var tapped = 0;
    await pumpPhone(tester,
        preceding: 340, onAction: () => tapped++, size: const Size(390, 667));
    expect(tester.getTopLeft(find.byIcon(Icons.inbox_outlined)).dy,
        greaterThanOrEqualTo(340));
    await tester.tap(find.byType(FilledButton));
    expect(tapped, 1);
  });

  testWidgets('tela reconstruída ao rolar: o botão acompanha o dedo',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var tapped = 0;
    await pumpPhone(tester, preceding: 340, onAction: () => tapped++);
    final start = tester.getRect(find.byType(FilledButton));

    final gesture = await tester.startGesture(const Offset(195, 750));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    final moved = tester.getRect(find.byType(FilledButton)).top;
    tester.element(find.byType(EmptyState)).markNeedsBuild();
    await tester.pump();
    await tester.pump();
    // Não fica "fixo" na tela enquanto o resto rola.
    expect(tester.getRect(find.byType(FilledButton)).top, closeTo(moved, 1));
    expect(moved, lessThan(start.top));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
        tester.getRect(find.byType(FilledButton)).top, closeTo(start.top, 1));
    await tester.tap(find.byType(FilledButton));
    expect(tapped, 1);
    // O override tem que voltar antes das verificações do fim do teste.
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('centerOnScreen false fica onde foi colocada', (tester) async {
    final bodyKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScreenBodyScope(
          bodyKey: bodyKey,
          child: KeyedSubtree(
            key: bodyKey,
            child: const Column(
              children: [
                EmptyState(message: 'Seção vazia.', centerOnScreen: false),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('Seção vazia.')).dy, lessThan(200));
  });
}
