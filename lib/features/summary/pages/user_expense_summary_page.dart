import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/services/auth_repository.dart';
import '../../events/services/events_repository.dart';
import '../../expenses/services/expense_categories_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../models/user_expense_summary_model.dart';
import '../services/user_expense_summary_repository.dart';

class UserExpenseSummaryPage extends ConsumerStatefulWidget {
  const UserExpenseSummaryPage({super.key});

  @override
  ConsumerState<UserExpenseSummaryPage> createState() =>
      _UserExpenseSummaryPageState();
}

class _UserExpenseSummaryPageState
    extends ConsumerState<UserExpenseSummaryPage> {
  String? userId;
  String? groupId;
  String? eventId;
  String? category;
  DateTime? from;
  DateTime? to;
  Future<UserExpenseSummaryModel>? summaryFuture;

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return AppScaffold(
      title: 'Extrato',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return const Text('Voce nao participa de nenhum grupo.');
              }
              if (groupId == null ||
                  groups.every((group) => group.id != groupId)) {
                groupId = groups.first.id;
                ref.read(selectedGroupIdProvider.notifier).state = groupId;
              }
              return DropdownButtonFormField<String>(
                initialValue: groupId,
                decoration: const InputDecoration(labelText: 'Grupo'),
                items: groups
                    .map((group) => DropdownMenuItem(
                        value: group.id, child: Text(group.name)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      groupId = value;
                      userId = null;
                      eventId = null;
                      summaryFuture = null;
                    });
                    ref.read(selectedGroupIdProvider.notifier).state = value;
                  }
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro ao carregar grupos: $error'),
          ),
          const SizedBox(height: 12),
          if (groupId != null)
            currentUserAsync.when(
              data: (currentUser) {
                if (currentUser == null) {
                  return const SizedBox.shrink();
                }
                final role = ref.watch(groupRoleProvider(groupId!)).valueOrNull;
                if (role != 'ADMIN') {
                  userId = currentUser.id;
                  return Text('Extrato: ${currentUser.nickname}');
                }
                return FutureBuilder(
                  future:
                      ref.read(groupsRepositoryProvider).listMembers(groupId!),
                  builder: (context, snapshot) {
                    final members = snapshot.data ?? [];
                    return DropdownButtonFormField<String?>(
                      initialValue: userId,
                      decoration: const InputDecoration(labelText: 'Extrato'),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('Consolidado do grupo')),
                        ...members.map((member) => DropdownMenuItem<String?>(
                            value: member.userId,
                            child: Text(member.nickname))),
                      ],
                      onChanged: (value) => setState(() => userId = value),
                    );
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => const SizedBox.shrink(),
            ),
          const SizedBox(height: 12),
          eventsAsync.when(
            data: (events) => DropdownButtonFormField<String?>(
              initialValue: eventId,
              decoration: const InputDecoration(labelText: 'Evento'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Todos')),
                ...events.map((event) => DropdownMenuItem<String?>(
                    value: event.id, child: Text(event.name))),
              ],
              onChanged: (value) => setState(() => eventId = value),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro ao carregar eventos: $error'),
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) => DropdownButtonFormField<String?>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Tipo de despesa'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Todos')),
                ...categories.map((item) => DropdownMenuItem<String?>(
                    value: item.name, child: Text(item.name))),
              ],
              onChanged: (value) => setState(() => category = value),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro ao carregar tipos: $error'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async => _pickDate(context, true),
                icon: const Icon(Icons.date_range),
                label: Text(from == null ? 'Data inicial' : _formatDate(from!)),
              ),
              OutlinedButton.icon(
                onPressed: () async => _pickDate(context, false),
                icon: const Icon(Icons.date_range),
                label: Text(to == null ? 'Data final' : _formatDate(to!)),
              ),
              FilledButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.search),
                label: const Text('Buscar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (summaryFuture != null)
            FutureBuilder<UserExpenseSummaryModel>(
              future: summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Erro ao carregar extrato: ${snapshot.error}');
                }
                return _SummaryContent(summary: snapshot.data!);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, bool start) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (selected != null) {
      setState(() {
        if (start) {
          from = selected;
        } else {
          to = selected;
        }
      });
    }
  }

  void _loadSummary() {
    if (groupId == null) {
      return;
    }
    setState(() {
      summaryFuture = ref.read(userExpenseSummaryRepositoryProvider).get(
            groupId: groupId!,
            userId: userId,
            from: from,
            to: to,
            category: category,
            eventId: eventId,
          );
    });
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary});

  final UserExpenseSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
                label: 'Consumiu', value: _formatMoney(summary.totalConsumed)),
            _Metric(label: 'Pagou', value: _formatMoney(summary.totalPaid)),
            _Metric(label: 'Saldo', value: _formatMoney(summary.balance)),
          ],
        ),
        const SizedBox(height: 16),
        if (summary.expenses.isEmpty)
          const Text('Nenhuma despesa encontrada.')
        else
          ...summary.expenses.map(
            (expense) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(expense.description),
              subtitle: Text(
                  '${_formatDate(expense.expenseDate)} | ${expense.category}'),
              trailing: Text(_formatMoney(expense.amount)),
            ),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatMoney(double value) {
  return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
