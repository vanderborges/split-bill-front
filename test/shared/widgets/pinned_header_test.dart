import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/widgets/pinned_header.dart';

void main() {
  testWidgets('ao abrir a tela o conteúdo já aparece no lugar, sem pular',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PinnedHeaderLayout(
          header: const SizedBox(height: 120, child: Text('FILTRO')),
          builder: (context, top) => ListView(children: [
            SizedBox(height: top),
            const Text('PRIMEIRO ITEM'),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final finalY = tester.getTopLeft(find.text('PRIMEIRO ITEM')).dy;
    expect(finalY, greaterThan(120));

    // Reabre a tela e olha cada quadro: o item só aparece já no lugar final.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PinnedHeaderLayout(
          header: const SizedBox(height: 120, child: Text('FILTRO')),
          builder: (context, top) => ListView(children: [
            SizedBox(height: top),
            const Text('PRIMEIRO ITEM'),
          ]),
        ),
      ),
    ));
    expect(find.text('FILTRO'), findsOneWidget);
    for (var frame = 0; frame < 3; frame++) {
      final item = find.text('PRIMEIRO ITEM');
      if (item.evaluate().isNotEmpty) {
        expect(tester.getTopLeft(item).dy, finalY, reason: 'quadro $frame');
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('PRIMEIRO ITEM'), findsOneWidget);
  });

  testWidgets('sem cabeçalho o conteúdo aparece no primeiro quadro',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PinnedHeaderLayout(
          header: null,
          builder: (context, top) => const Text('CONTEUDO'),
        ),
      ),
    ));
    expect(find.text('CONTEUDO'), findsOneWidget);
  });
}
