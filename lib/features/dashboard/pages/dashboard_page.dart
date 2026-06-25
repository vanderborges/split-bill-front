import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/services/auth_repository.dart';
import '../../events/services/events_repository.dart';
import '../../groups/models/group_model.dart';
import '../../groups/services/groups_repository.dart';
import '../../reports/services/reports_repository.dart';

final dashboardGroupBalancesProvider =
    FutureProvider<List<_GroupBalance>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return [];
  }

  final groups = await ref.watch(groupsProvider.future);
  final eventsRepository = ref.watch(eventsRepositoryProvider);
  final reportsRepository = ref.watch(reportsRepositoryProvider);

  final balances = <_GroupBalance>[];
  for (final group in groups) {
    var balance = 0.0;

    try {
      final events = await eventsRepository.list(groupId: group.id);
      final openEvents = events.where((event) => event.status == 'OPEN');

      for (final event in openEvents) {
        try {
          final report = await reportsRepository.getEventReport(event.id);
          final userBalances =
              report.balances.where((item) => item.userId == user.id);
          if (userBalances.isNotEmpty) {
            balance += userBalances.first.balance;
          }
        } catch (_) {
          balance += 0;
        }
      }
    } catch (_) {
      balance = 0;
    }

    balances.add(_GroupBalance(group: group, balance: balance));
  }

  return balances;
});

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

class _BalancesContent extends StatelessWidget {
  const _BalancesContent({required this.balances});

  final List<_GroupBalance> balances;

  @override
  Widget build(BuildContext context) {
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
                title: groupBalance.group.name,
                balance: groupBalance.balance,
                icon: Icons.groups_outlined,
              ),
            ),
          ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.balance,
    required this.icon,
  });

  final String title;
  final double balance;
  final IconData icon;

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
      ),
    );
  }
}

class _GroupBalance {
  const _GroupBalance({
    required this.group,
    required this.balance,
  });

  final GroupModel group;
  final double balance;
}

String _formatMoney(double value) {
  return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}
