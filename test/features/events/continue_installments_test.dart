import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/features/events/models/pending_installment_model.dart';
import 'package:split_bill_front/features/events/pages/events_page.dart';

const _course = PendingInstallmentModel(
  installmentGroupId: 'curso',
  description: 'Curso',
  amount: 100,
  installmentNumber: 2,
  totalInstallments: 3,
  subscription: false,
);
const _streaming = PendingInstallmentModel(
  installmentGroupId: 'streaming',
  description: 'Streaming',
  amount: 40,
  installmentNumber: 2,
  totalInstallments: null,
  subscription: true,
);

Future<void> _open(
    WidgetTester tester, void Function(List<String>?) onResult) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => onResult(await askInstallmentsToContinue(
              context, const [_course, _streaming], '12/2026')),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra o que vai seguir, com tudo marcado', (tester) async {
    List<String>? result;
    await _open(tester, (value) => result = value);

    expect(find.textContaining('Parcela 2 de 3'), findsOneWidget);
    expect(find.textContaining('Assinatura'), findsOneWidget);

    await tester.tap(find.text('Criar 12/2026'));
    await tester.pumpAndSettle();
    expect(result, unorderedEquals(['curso', 'streaming']));
  });

  testWidgets('desmarcar tira só aquela despesa', (tester) async {
    List<String>? result;
    await _open(tester, (value) => result = value);

    await tester.tap(find.text('Streaming'));
    await tester.pump();
    await tester.tap(find.text('Criar 12/2026'));
    await tester.pumpAndSettle();
    expect(result, ['curso']);
  });

  testWidgets('cancelar não cria o mês', (tester) async {
    var result = <String>['não respondeu'] as List<String>?;
    await _open(tester, (value) => result = value);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
