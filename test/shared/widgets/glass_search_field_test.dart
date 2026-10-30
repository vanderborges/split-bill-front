import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/core/theme/app_theme.dart';
import 'package:split_bill_front/shared/ptbr_sort.dart';
import 'package:split_bill_front/shared/widgets/glass.dart';
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
      home: Scaffold(body: AppSearchField(onChanged: typed.add)),
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

  testWidgets('mesma aparência dos campos de filtro (sem vidro)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: AppSearchField(onChanged: (_) {})),
    ));
    final decoration =
        tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
    // Fundo preenchido do tema, igual ao "Filtrar por grupo".
    expect(decoration.filled, isTrue);
    expect(find.byType(GlassSurface), findsNothing);
  });
}
