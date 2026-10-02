import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../events/services/events_repository.dart';
import '../../expenses/services/expenses_repository.dart';
import '../../expenses/services/new_expense_intent.dart';
import '../../groups/services/groups_repository.dart';
import '../models/dashboard_group_balance_model.dart';
import '../services/dashboard_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(dashboardGroupBalancesProvider);

    return AppScaffold(
      title: 'Início',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Bora dividir uma conta?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () {
              ref.read(pendingAutoOpenExpenseProvider.notifier).state = true;
              context.go('/expenses');
            },
            icon: const Icon(Icons.add),
            label: const Text('Nova despesa'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Saldo por grupo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Mostrando apenas os grupos em que você participa.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          balancesAsync.when(
            data: (balances) => _BalancesContent(balances: balances),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: LoadingState(),
            ),
            error: (_, __) => ErrorState(
              message: 'Não foi possível carregar seus saldos.',
              onRetry: () => ref.invalidate(dashboardGroupBalancesProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancesContent extends ConsumerWidget {
  const _BalancesContent({required this.balances});

  final List<DashboardGroupBalanceModel> balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (balances.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'Você ainda não participa de grupos.',
        message: 'Crie ou entre em um grupo para começar a dividir despesas.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: balances
          .map((groupBalance) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _GroupCard(groupBalance: groupBalance),
              ))
          .toList(),
    );
  }
}

void _openEventExpenses(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  String eventId,
) {
  ref.read(selectedGroupIdProvider.notifier).state = groupId;
  ref.read(selectedEventIdProvider.notifier).state = eventId;
  ref.invalidate(selectedEventProvider);
  ref.invalidate(selectedEventExpensesProvider);
  context.go('/expenses');
}

/// Grupo como cartão expansível: um grupo pode ter mais de um evento em
/// aberto ao mesmo tempo (ex.: dois meses, ou um mês + um avulso) — somar
/// tudo num único saldo escondia o que estava acontecendo em cada evento.
/// Aqui cada evento com despesa da pessoa aparece com o próprio saldo.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.groupBalance});

  final DashboardGroupBalanceModel groupBalance;

  @override
  Widget build(BuildContext context) {
    final events = groupBalance.events;

    if (events.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.groups_outlined),
          title: Text(groupBalance.groupName),
          subtitle: const Text('Sem despesas em eventos abertos.'),
        ),
      );
    }

    if (events.length == 1) {
      return Card(
        child: Consumer(
          builder: (context, ref, _) => ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(groupBalance.groupName),
            subtitle: Text(_eventSubtitle(events.first)),
            trailing: MoneyText(
              events.first.balance,
              colorBySign: true,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _openEventExpenses(
                context, ref, groupBalance.groupId, events.first.eventId),
          ),
        ),
      );
    }

    final total =
        events.fold<double>(0, (sum, event) => sum + event.balance);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.groups_outlined),
        title: Text(groupBalance.groupName),
        subtitle: Text('${events.length} eventos em aberto'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyText(
              total,
              colorBySign: true,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: events
            .map((event) => Consumer(
                  builder: (context, ref, _) => ListTile(
                    title: Text(event.eventName),
                    subtitle: Text(_eventSubtitle(event)),
                    trailing: MoneyText(event.balance, colorBySign: true),
                    onTap: () => _openEventExpenses(context, ref,
                        groupBalance.groupId, event.eventId),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

String _eventSubtitle(DashboardEventBalanceModel event) {
  final status = switch (event.eventStatus) {
    'SETTLING' => 'Aguardando pagamento — ',
    _ => '',
  };
  final balance = event.balance < 0
      ? 'Você tem a pagar'
      : event.balance > 0
          ? 'Você tem a receber'
          : 'Sem saldo em aberto';
  return '$status$balance';
}
