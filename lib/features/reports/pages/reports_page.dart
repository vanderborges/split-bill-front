import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../events/services/events_repository.dart';
import '../../expenses/services/expenses_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../../months/services/months_repository.dart';
import '../../settlements/models/event_settlement_model.dart';
import '../../settlements/services/event_settlements_repository.dart';
import '../models/monthly_report_model.dart';
import '../services/reports_repository.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(selectedEventProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final reportAsync = ref.watch(selectedEventReportProvider);
    final settlementsAsync = ref.watch(selectedEventSettlementsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final isGroupAdmin = eventAsync.valueOrNull != null
        ? ref
                .watch(groupRoleProvider(eventAsync.valueOrNull!.groupId))
                .valueOrNull ==
            'ADMIN'
        : false;

    return AppScaffold(
      title: 'Relatorios',
      child: reportAsync.when(
        data: (report) {
          if (report == null) {
            return const Center(
                child: Text(
                    'Crie ou selecione um evento antes de visualizar o relatorio.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              groupsAsync.when(
                data: (groups) => DropdownButtonFormField<String?>(
                  initialValue: selectedGroupId,
                  decoration: const InputDecoration(labelText: 'Grupo'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Todos os grupos')),
                    ...groups.map((group) => DropdownMenuItem<String?>(
                        value: group.id, child: Text(group.name))),
                  ],
                  onChanged: (value) {
                    ref.read(selectedGroupIdProvider.notifier).state = value;
                    ref.read(selectedEventIdProvider.notifier).state = null;
                    ref.invalidate(selectedEventProvider);
                    ref.invalidate(selectedEventReportProvider);
                    ref.invalidate(selectedEventSettlementsProvider);
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Erro ao carregar grupos: $error'),
              ),
              const SizedBox(height: 12),
              eventAsync.when(
                data: (event) => eventsAsync.when(
                  data: (events) => DropdownButtonFormField<String>(
                    initialValue: event?.id,
                    decoration: const InputDecoration(labelText: 'Evento'),
                    items: events
                        .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                                _eventLabel(item, groupsAsync.valueOrNull))))
                        .toList(),
                    onChanged: (value) {
                      ref.read(selectedEventIdProvider.notifier).state = value;
                      ref.invalidate(selectedEventProvider);
                      ref.invalidate(selectedEventReportProvider);
                      ref.invalidate(selectedEventSettlementsProvider);
                      ref.invalidate(selectedEventExpensesProvider);
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Text('${report.groupName} | ${report.eventName ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Relatorio ${report.eventName ?? '${report.month.toString().padLeft(2, '0')}/${report.year}'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Chip(
                      label: Text(
                          report.status == 'CLOSED' ? 'Fechado' : 'Aberto')),
                  const SizedBox(width: 8),
                  if (report.status == 'OPEN' && isGroupAdmin)
                    FilledButton(
                      onPressed: report.eventId == null
                          ? null
                          : () =>
                              _confirmCloseEvent(context, ref, report.eventId!),
                      child: const Text('Fechar evento'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Total de despesas: ${_formatMoney(report.totalExpenses)}'),
              const SizedBox(height: 16),
              settlementsAsync.when(
                data: (settlements) => _ReportTable(
                  balances: report.balances,
                  settlements: settlements,
                  canUpdateSettlements: isGroupAdmin,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Text('Erro ao carregar pagamentos: $error'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar relatorio: $error')),
      ),
    );
  }
}

class _ReportTable extends ConsumerWidget {
  const _ReportTable({
    required this.balances,
    required this.settlements,
    required this.canUpdateSettlements,
  });

  final List<MonthlyBalanceModel> balances;
  final List<EventSettlementModel> settlements;
  final bool canUpdateSettlements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsByUser = {
      for (final settlement in settlements) settlement.userId: settlement,
    };
    final sortedBalances = [...balances]..sort((first, second) {
        final firstSettlement = settlementsByUser[first.userId];
        final secondSettlement = settlementsByUser[second.userId];
        final statusComparison = _statusOrder(firstSettlement)
            .compareTo(_statusOrder(secondSettlement));
        if (statusComparison != 0) {
          return statusComparison;
        }
        return first.nickname.compareTo(second.nickname);
      });

    return Column(
      children: sortedBalances.map((balance) {
        final settlement = settlementsByUser[balance.userId];
        final color = balance.balance < 0
            ? const Color.fromRGBO(244, 67, 54, 0.14)
            : balance.balance > 0
                ? const Color.fromRGBO(76, 175, 80, 0.14)
                : Colors.transparent;
        final balanceColor = balance.balance < 0
            ? Colors.red.shade700
            : balance.balance > 0
                ? Colors.green.shade700
                : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final name = Text(
                balance.nickname,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              );
              final amount = Text(
                _formatMoney(balance.balance),
                textAlign: compact ? TextAlign.left : TextAlign.right,
                style: TextStyle(
                  color: balanceColor,
                  fontWeight: FontWeight.w700,
                ),
              );
              final status = DropdownButton<String>(
                value: settlement?.normalizedStatus ?? 'PENDING',
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'PENDING', child: Text('Pendente')),
                  DropdownMenuItem(value: 'PAID', child: Text('Pago')),
                ],
                onChanged: !canUpdateSettlements ||
                        settlement == null ||
                        settlement.amount == 0
                    ? null
                    : (value) async {
                        if (value == null) {
                          return;
                        }
                        await _updateSettlement(
                            context, ref, settlement, value);
                      },
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    name,
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: amount),
                        const SizedBox(width: 12),
                        status,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: name),
                  SizedBox(width: 110, child: amount),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 112,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: status,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

int _statusOrder(EventSettlementModel? settlement) {
  if (settlement?.normalizedStatus == 'PAID') {
    return 1;
  }
  return 0;
}

Future<void> _updateSettlement(
  BuildContext context,
  WidgetRef ref,
  EventSettlementModel settlement,
  String status,
) async {
  try {
    await ref.read(eventSettlementsRepositoryProvider).updateStatus(
          eventId: settlement.eventId,
          settlementId: settlement.id,
          status: status,
        );
    ref.invalidate(selectedEventSettlementsProvider);
    ref.invalidate(selectedEventReportProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Nao foi possivel atualizar pagamento: ${_errorMessage(error)}')),
      );
    }
  }
}

String _errorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (error.response?.statusCode == 403) {
      return 'apenas admins do grupo podem alterar pagamentos';
    }
    if (error.message != null) {
      return error.message!;
    }
  }
  return error.toString();
}

Future<void> _confirmCloseEvent(
    BuildContext context, WidgetRef ref, String eventId) async {
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Fechar evento'),
        content: const Text(
            'Depois de fechado, o evento nao permite novas alteracoes. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Fechar')),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    await ref.read(eventsRepositoryProvider).close(eventId);
    ref.invalidate(monthsProvider);
    ref.invalidate(currentMonthProvider);
    ref.invalidate(currentMonthReportProvider);
    ref.invalidate(currentMonthExpensesProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(selectedEventProvider);
    ref.invalidate(selectedEventReportProvider);
    ref.invalidate(selectedEventExpensesProvider);
    ref.invalidate(selectedEventSettlementsProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento fechado com sucesso.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel fechar o evento: $error')),
      );
    }
  }
}

String _formatMoney(double value) {
  return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

String _groupName(List<dynamic>? groups, String groupId) {
  if (groups == null) {
    return 'Grupo';
  }
  for (final group in groups) {
    if (group.id == groupId) {
      return group.name as String;
    }
  }
  return 'Grupo';
}

String _eventLabel(dynamic event, List<dynamic>? groups) {
  return '${event.name} | ${_groupName(groups, event.groupId)}';
}
