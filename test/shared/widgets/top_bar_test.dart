import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/widgets/glass.dart';

void main() {
  testWidgets('lista por trás da barra: recuo = margem do aparelho + barra',
      (tester) async {
    double? outside;
    double? inside;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 47)),
        child: Builder(builder: (pageContext) {
          outside = topBarInset(pageContext);
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: glassAppBar(pageContext, title: 'Teste', actions: []),
            body: Builder(builder: (bodyContext) {
              inside = topBarInset(bodyContext);
              return const SizedBox.expand();
            }),
          );
        }),
      ),
    ));
    expect(outside, 47 + kToolbarHeight);
    expect(inside, 47 + kToolbarHeight);
    // Barra sem fundo sólido: só o desfoque em degradê.
    expect(find.byType(TopEdgeBlur), findsOneWidget);
  });

  testWidgets('vidro sem sombra', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:
          Scaffold(body: GlassSurface(child: SizedBox(width: 40, height: 40))),
    ));
    final shadows = tester
        .widgetList<DecoratedBox>(find.descendant(
            of: find.byType(GlassSurface), matching: find.byType(DecoratedBox)))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => (decoration.boxShadow ?? []).isNotEmpty);
    expect(shadows, isEmpty);
  });
}
