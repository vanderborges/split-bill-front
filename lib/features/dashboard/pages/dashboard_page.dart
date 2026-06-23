import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../expenses/services/expenses_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../../months/services/months_repository.dart';
import '../../auth/services/auth_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final monthAsync = ref.watch(currentMonthProvider);
    final expensesAsync = ref.watch(currentMonthExpensesProvider);
    final group = ref.watch(selectedGroupProvider).valueOrNull;
    final isGroupAdmin = group != null &&
        ref.watch(groupRoleProvider(group.id)).valueOrNull == 'ADMIN';

    return AppScaffold(
      title: 'Dashboard',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            monthAsync.when(
              data: (month) => month == null
                  ? 'Nenhum mes aberto'
                  : 'Mes atual: ${month.label}',
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
                label: 'Consumiu',
                value: expensesAsync.when(
                  data: (expenses) =>
                      _formatMoney(_consumed(expenses, currentUser?.id)),
                  loading: () => '...',
                  error: (_, __) => _formatMoney(0),
                ),
              ),
              _MetricCard(
                  label: 'Pagou',
                  value: expensesAsync.when(
                      data: (expenses) =>
                          _formatMoney(_paid(expenses, currentUser?.id)),
                      loading: () => '...',
                      error: (_, __) => _formatMoney(0))),
              _MetricCard(
                  label: 'A receber',
                  value: expensesAsync.when(
                      data: (expenses) =>
                          _formatMoney(_receivable(expenses, currentUser?.id)),
                      loading: () => '...',
                      error: (_, __) => _formatMoney(0))),
              _MetricCard(
                  label: 'A pagar',
                  value: expensesAsync.when(
                      data: (expenses) =>
                          _formatMoney(_payable(expenses, currentUser?.id)),
                      loading: () => '...',
                      error: (_, __) => _formatMoney(0))),
              if (isGroupAdmin) _ParticipantMetric(groupId: group.id),
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

double _consumed(List<dynamic> expenses, String? userId) => userId == null
    ? 0
    : expenses
        .expand((expense) => expense.participants)
        .where((participant) => participant.userId == userId)
        .fold<double>(
            0, (total, participant) => total + participant.shareAmount);
double _paid(List<dynamic> expenses, String? userId) => userId == null
    ? 0
    : expenses
        .expand((expense) => expense.payers)
        .where((payer) => payer.userId == userId)
        .fold<double>(0, (total, payer) => total + payer.amount);
double _receivable(List<dynamic> expenses, String? userId) =>
    (_paid(expenses, userId) - _consumed(expenses, userId))
        .clamp(0, double.infinity)
        .toDouble();
double _payable(List<dynamic> expenses, String? userId) =>
    (_consumed(expenses, userId) - _paid(expenses, userId))
        .clamp(0, double.infinity)
        .toDouble();

class _ParticipantMetric extends ConsumerWidget {
  const _ParticipantMetric({required this.groupId});
  final String groupId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder(
        future: ref.watch(groupsRepositoryProvider).listMembers(groupId),
        builder: (context, snapshot) => _MetricCard(
            label: 'Participantes',
            value: snapshot.hasData ? snapshot.data!.length.toString() : '0'),
      );
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
