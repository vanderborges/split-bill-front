import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/shared/ptbr_sort.dart';
import 'package:split_bill_front/shared/widgets/glass_search_field.dart';

void main() {
  test('busca ignora acentos e maiúsculas', () {
    expect(matchesSearchPtBr('João Silva', 'joao'), isTrue);
    expect(matchesSearchPtBr('Viagem Floripa', 'FLOR'), isTrue);
    expect(matchesSearchPtBr('Churrasco', 'praia'), isFalse);
    expect(matchesSearchPtBr('Qualquer', ''), isTrue);
  });

  testWidgets('filtra enquanto digita e o x limpa', (tester) async {
    final typed = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchOverlay(
          search: GlassSearchField(onChanged: typed.add),
          child: ListView(),
        ),
      ),
    ));
    expect(find.byIcon(Icons.close), findsNothing);
    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pump();
    expect(typed.last, 'ana');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(typed.last, '');
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('lista começa abaixo do campo (rola por trás dele)',
      (tester) async {
    late double inset;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 40)),
        child: Builder(builder: (context) {
          inset = searchListTopInset(context);
          return const SizedBox();
        }),
      ),
    ));
    // Relógio (40) + barra (56) + respiro + campo + respiro.
    expect(inset, 40 + kToolbarHeight + 8 + glassSearchFieldHeight + 8);
  });
}
