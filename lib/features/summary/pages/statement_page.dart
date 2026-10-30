import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/pinned_header.dart';
import '../../reports/pages/reports_page.dart';

/// Extrato (aba da barra): filtros Grupo + Evento e só o card de saldo de
/// quem está logado, com as mesmas funções do card do Saldo (despesas,
/// Pagar). "Todos os eventos" mostra um card por evento. "Extrato geral"
/// abre o extrato completo por período.
class StatementPage extends ConsumerWidget {
  const StatementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEvents = ref.watch(statementAllEventsProvider);
    return AppScaffold(
      scrollsBehindTopBar: true,
      title: 'Extrato',
      // Grupo e Evento ficam fixos no topo (painel de vidro); o resto rola
      // por trás.
      child: PinnedHeaderLayout(
        header: const EventFilterFields(allowAllEvents: true),
        builder: (context, top) => ListView(
          padding:
              EdgeInsets.fromLTRB(16, top, 16, 16 + bottomBarInset(context)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go('/summary/general'),
                child: const Text('Extrato geral'),
              ),
            ),
            const SizedBox(height: 8),
            if (allEvents)
              const AllEventsStatementView()
            else
              const EventBalanceView(onlyCurrentUser: true),
          ],
        ),
      ),
    );
  }
}
