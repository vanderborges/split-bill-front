import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';
import '../../reports/pages/reports_page.dart';

/// Extrato (aba da barra): filtros Grupo + Evento e só o card de saldo de
/// quem está logado, com as mesmas funções do card do Saldo (despesas,
/// Pagar). "Extrato geral" abre o extrato completo por período.
class StatementPage extends ConsumerWidget {
  const StatementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Extrato',
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomBarInset(context)),
        children: [
          const EventFilterFields(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/summary/general'),
              child: const Text('Extrato geral'),
            ),
          ),
          const SizedBox(height: 8),
          const EventBalanceView(onlyCurrentUser: true),
        ],
      ),
    );
  }
}
