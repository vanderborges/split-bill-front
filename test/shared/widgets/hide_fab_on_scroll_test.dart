import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/widgets/hide_fab_on_scroll.dart';

void main() {
  Offset fabOffset(WidgetTester tester) =>
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset;

  testWidgets('hides the FAB scrolling down and brings it back scrolling up',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HideFabOnScroll(
        fab: FloatingActionButton(
            onPressed: () {}, child: const Icon(Icons.add)),
        body: ListView(
          children: [
            for (var i = 0; i < 100; i++) ListTile(title: Text('Item $i')),
          ],
        ),
        builder: (fab, body) => Scaffold(floatingActionButton: fab, body: body),
      ),
    ));
    expect(fabOffset(tester), Offset.zero);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(fabOffset(tester), isNot(Offset.zero));

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(fabOffset(tester), Offset.zero);
  });
}
