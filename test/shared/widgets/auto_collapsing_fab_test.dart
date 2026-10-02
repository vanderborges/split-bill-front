import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/core/theme/app_theme.dart';
import 'package:split_bill_front/shared/widgets/auto_collapsing_fab.dart';

Widget _wrap(Widget fab) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(floatingActionButton: fab),
  );
}

void main() {
  testWidgets('starts expanded showing the label', (tester) async {
    await tester.pumpWidget(_wrap(AutoCollapsingFab(
      label: 'Nova despesa',
      onPressed: () {},
    )));

    expect(find.text('Nova despesa'), findsOneWidget);
  });

  testWidgets('collapses to icon-only after the configured delay',
      (tester) async {
    await tester.pumpWidget(_wrap(AutoCollapsingFab(
      label: 'Nova despesa',
      collapseAfter: const Duration(milliseconds: 500),
      onPressed: () {},
    )));

    expect(find.text('Nova despesa'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Nova despesa'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('tapping while expanded triggers onPressed and collapses',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(AutoCollapsingFab(
      label: 'Novo grupo',
      collapseAfter: const Duration(seconds: 10),
      onPressed: () => tapped = true,
    )));

    await tester.tap(find.text('Novo grupo'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(find.text('Novo grupo'), findsNothing);
  });
}
