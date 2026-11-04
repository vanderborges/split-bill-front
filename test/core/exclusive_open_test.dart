import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_bill_front/core/routes/exclusive_open.dart';

void main() {
  test('falha ao abrir não prende a trava', () async {
    await expectLater(openExclusive(() async => throw StateError('sem rede')),
        throwsStateError);
    expect(isExclusiveOpen, isFalse);
  });

  testWidgets('toque repetido enquanto carrega abre só uma tela',
      (tester) async {
    final loading = Completer<void>();
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(children: [
            TextButton(
              onPressed: () => openExclusive(() async {
                await loading.future;
                opened++;
                if (context.mounted) {
                  await Navigator.of(context).push<void>(MaterialPageRoute(
                      builder: (_) => const Scaffold(body: Text('Form'))));
                }
              }),
              child: const Text('Nova despesa'),
            ),
            // Outra tela da mesma página também espera a primeira.
            TextButton(
              onPressed: () => openExclusive(() async => opened++),
              child: const Text('Editar'),
            ),
          ]),
        ),
      ),
    ));

    await tester.tap(find.text('Nova despesa'));
    await tester.tap(find.text('Nova despesa'));
    await tester.tap(find.text('Editar'));
    loading.complete();
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text('Form'), findsOneWidget);
    expect(isExclusiveOpen, isTrue);

    // Fechou: pode abrir de novo.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(isExclusiveOpen, isFalse);
    await tester.tap(find.text('Editar'));
    await tester.pump();
    expect(opened, 2);
  });

  testWidgets('trocar de rota com o form e um pop-up abertos libera a trava',
      (tester) async {
    // Ex.: sessão encerrada: o form some sem ninguém fechar.
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => openExclusive(() async {
              await Navigator.of(context).push<void>(MaterialPageRoute(
                  builder: (formContext) => Scaffold(
                        body: TextButton(
                          onPressed: () => showDialog<void>(
                              context: formContext,
                              builder: (_) =>
                                  const AlertDialog(title: Text('Pop-up'))),
                          child: const Text('Abrir pop-up'),
                        ),
                      )));
            }),
            child: const Text('Abrir form'),
          ),
        ),
      ),
      GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('Login'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('Abrir form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir pop-up'));
    await tester.pumpAndSettle();
    expect(isExclusiveOpen, isTrue);

    router.go('/login');
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(isExclusiveOpen, isFalse);
  });
}
