import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../expenses/services/expenses_repository.dart';
import '../../months/services/months_repository.dart';
import '../../users/services/users_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final monthAsync = ref.watch(currentMonthProvider);
    final expensesAsync = ref.watch(currentMonthExpensesProvider);

    return AppScaffold(
      title: 'Dashboard',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            monthAsync.when(
              data: (month) => month == null ? 'Nenhum mes aberto' : 'Mes atual: ${month.label}',
              loading: () => 'Carregando mes atual...',
              error: (_, __) => 'Erro ao carregar mes atual',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: 'Despesas',
                value: expensesAsync.when(
                  data: (expenses) => _formatMoney(
                    expenses.fold<double>(0.0, (total, expense) => total + expense.amount),
                  ),
                  loading: () => '...',
                  error: (_, __) => 'Erro',
                ),
              ),
              _MetricCard(
                label: 'Participantes',
                value: usersAsync.when(
                  data: (users) => users.length.toString(),
                  loading: () => '...',
                  error: (_, __) => 'Erro',
                ),
              ),
              const _MetricCard(label: 'A receber', value: 'R\$ 0,00'),
              const _MetricCard(label: 'A pagar', value: 'R\$ 0,00'),
            ],
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

String _formatMoney(double value) {
  return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
