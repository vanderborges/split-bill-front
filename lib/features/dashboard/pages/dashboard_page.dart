import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../events/services/events_repository.dart';
import '../../expenses/services/expenses_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../models/dashboard_group_balance_model.dart';
import '../services/dashboard_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(dashboardGroupBalancesProvider);

    return AppScaffold(
      title: 'Dashboard',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Saldo por grupo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Mostrando apenas os grupos em que voce participa.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          balancesAsync.when(
            data: (balances) => _BalancesContent(balances: balances),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const _BalancesContent(balances: []),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/expenses'),
            icon: const Icon(Icons.add),
            label: const Text('Nova despesa'),
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
    final total = balances.fold<double>(0, (sum, group) => sum + group.balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BalanceCard(
          title: 'Saldo total',
          balance: total,
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 12),
        if (balances.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Voce ainda nao participa de grupos.'),
            ),
          )
        else
          ...balances.map(
            (groupBalance) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
    final color = balance < 0
        ? Colors.red
        : balance > 0
            ? Colors.green
            : Theme.of(context).colorScheme.onSurfaceVariant;
    final subtitle = balance < 0
        ? 'Voce tem a pagar'
        : balance > 0
            ? 'Voce tem a receber'
            : 'Sem saldo em aberto';

    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          _formatMoney(balance),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
        onTap: onTap,
      ),
    );
  }
}

String _formatMoney(double value) {
  return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}
