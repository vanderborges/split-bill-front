import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/core/theme/app_theme.dart';
import 'package:split_bill_front/shared/widgets/empty_state.dart';
import 'package:split_bill_front/shared/widgets/error_state.dart';
import 'package:split_bill_front/shared/widgets/status_badge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
}

void main() {
  testWidgets('StatusBadge shows the default label per status',
      (tester) async {
    await tester.pumpWidget(_wrap(const StatusBadge(AppStatus.quitado)));
    expect(find.text('Quitado'), findsOneWidget);
  });

  testWidgets('StatusBadge accepts a custom label', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusBadge(AppStatus.pendente, label: 'Aguardando')),
    );
    expect(find.text('Aguardando'), findsOneWidget);
    expect(find.text('Pendente'), findsNothing);
  });

  testWidgets('EmptyState shows message and triggers the CTA',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        EmptyState(
          message: 'Você ainda não tem eventos.',
          actionLabel: 'Criar evento',
          onAction: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Você ainda não tem eventos.'), findsOneWidget);
    await tester.tap(find.text('Criar evento'));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorState shows the retry action when provided',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(ErrorState(onRetry: () => retried = true)),
    );

    await tester.tap(find.text('Tentar novamente'));
    expect(retried, isTrue);
  });

  testWidgets('ErrorState hides the retry action when omitted',
      (tester) async {
    await tester.pumpWidget(const _NoRetryErrorState());
    expect(find.text('Tentar novamente'), findsNothing);
  });
}

class _NoRetryErrorState extends StatelessWidget {
  const _NoRetryErrorState();

  @override
  Widget build(BuildContext context) {
    return _wrap(const ErrorState());
  }
}
