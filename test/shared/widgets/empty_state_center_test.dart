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
