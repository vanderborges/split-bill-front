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

    final total =
        balances.fold<double>(0, (sum, group) => sum + group.balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BalanceCard(
          title: 'Saldo total',
          balance: total,
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...balances.map(
          (groupBalance) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _BalanceCard(
              title: groupBalance.groupName,
              balance: groupBalance.balance,
              icon: Icons.groups_outlined,
              onTap: () =>
                  _openGroupExpenses(context, ref, groupBalance.groupId),
            ),
          ),
        ),
      ],
    );
  }
}

void _openGroupExpenses(BuildContext context, WidgetRef ref, String groupId) {
  ref.read(selectedGroupIdProvider.notifier).state = groupId;
  ref.read(selectedEventIdProvider.notifier).state = null;
  ref.invalidate(selectedEventProvider);
  ref.invalidate(selectedEventExpensesProvider);
  context.go('/expenses');
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.balance,
    required this.icon,
    this.onTap,
  });

  final String title;
  final double balance;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = balance < 0
        ? 'Você tem a pagar'
        : balance > 0
            ? 'Você tem a receber'
            : 'Sem saldo em aberto';

    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: MoneyText(
          balance,
          colorBySign: true,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: onTap,
      ),
    );
  }
}
