import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/widgets/app_scaffold.dart';

void main() {
  Future<int Function()> pumpPage(WidgetTester tester) async {
    var backs = 0;
    await tester.pumpWidget(MaterialApp(
      home: SwipeBack(
        onBack: () => backs++,
        child: const Scaffold(body: Center(child: Text('Tela'))),
      ),
    ));
    return () => backs;
  }

  testWidgets('arrastar da borda esquerda pra direita volta', (tester) async {
    final backs = await pumpPage(tester);
    await tester.dragFrom(const Offset(5, 300), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(backs(), 1);
  });

  testWidgets('arraste curto não volta', (tester) async {
    final backs = await pumpPage(tester);
    final gesture = await tester.startGesture(const Offset(5, 300));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(backs(), 0);
  });

  testWidgets('arrastar no meio da tela não volta', (tester) async {
    final backs = await pumpPage(tester);
    await tester.dragFrom(const Offset(200, 300), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(backs(), 0);
  });

  testWidgets('voltar do sistema chama a seta', (tester) async {
    final backs = await pumpPage(tester);
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();
    expect(backs(), 1);
  });
}
