import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/api_error.dart';
import '../../../shared/ptbr_sort.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/services/auth_repository.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../events/services/events_repository.dart';
import '../../events/widgets/event_picker_field.dart';
import '../../events/widgets/receiver_choice.dart';
import '../../expenses/services/expenses_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../../months/services/months_repository.dart';
import '../../settlements/models/event_settlement_model.dart';
import '../../settlements/models/my_payment_model.dart';
import '../../settlements/services/event_settlements_repository.dart';
import '../models/balance_expense_detail_model.dart';
import '../models/monthly_report_model.dart';
import '../services/reports_repository.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(selectedEventProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroupId = ref.watch(selectedGroupIdProvider);

    return AppScaffold(
      title: 'Relatórios',
      // Os seletores de grupo/evento ficam sempre visíveis, mesmo sem
      // nenhum relatório ainda — antes ficavam escondidos atrás do estado
      // vazio, e quem não tinha nada cadastrado não via nem a lista de
      // grupos pra navegar.
      child: ListView(
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
              data: (events) => events.isEmpty
                  ? const Text('Nenhum evento cadastrado neste grupo.')
                  : EventPickerField(
                      key: ValueKey(event?.id),
                      events: events,
                      selectedId: event?.id,
                      groupNameOf: (groupId) =>
                          _groupName(groupsAsync.valueOrNull, groupId),
                      onChanged: (value) {
                        final picked = events.where((item) => item.id == value);
                        if (picked.isNotEmpty) {
                          selectEvent(ref,
                              groupId: picked.first.groupId, eventId: value);
                        }
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
          const EventBalanceView(),
        ],
      ),
    );
  }
}

/// Saldo do evento selecionado: status, ações do evento (Fechar, cobrança,
/// Concluir), compartilhar, total e os cards de saldo com pagamento. Usado
/// no Relatório e na visão "Saldo" da tela de Despesas.
class EventBalanceView extends ConsumerWidget {
  const EventBalanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(selectedEventProvider);
    final reportAsync = ref.watch(selectedEventReportProvider);
    final settlementsAsync = ref.watch(selectedEventSettlementsProvider);
    final isGroupAdmin = eventAsync.valueOrNull != null
        ? ref
                .watch(groupRoleProvider(eventAsync.valueOrNull!.groupId))
                .valueOrNull ==
            'ADMIN'
        : false;

    return reportAsync.when(
      data: (report) {
        if (report == null) {
          return const EmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'Nenhum relatório para mostrar.',
            message: 'Crie ou selecione um evento para ver o relatório.',
          );
        }
        // Sem título/status aqui: o status fica na lista do seletor de
        // evento. Sem nenhum botão de ação, os cards sobem; com o evento
        // fechado não tem compartilhar.
        final hasActions = isGroupAdmin &&
            (report.status == 'OPEN' || report.status == 'SETTLING');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasActions) ...[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (report.status == 'OPEN' && isGroupAdmin)
                    FilledButton(
                      onPressed: report.eventId == null
                          ? null
                          : () => _confirmStartSettlement(
                              context, ref, report.groupId, report.eventId!),
                      child: const Text('Fechar evento'),
                    ),
                  if (report.status == 'SETTLING' && isGroupAdmin)
                    OutlinedButton.icon(
                      onPressed: report.eventId == null
                          ? null
                          : () =>
                              _sendBillingAlert(context, ref, report.eventId!),
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Enviar alerta de cobrança'),
                    ),
                  if (report.status == 'SETTLING' && isGroupAdmin)
                    Tooltip(
                      message: _hasPendingSettlement(settlementsAsync)
                          ? 'Confirme todos os pagamentos antes de concluir o evento.'
                          : '',
                      child: FilledButton(
                        onPressed: report.eventId == null ||
                                _hasPendingSettlement(settlementsAsync)
                            ? null
                            : () => _confirmCloseEvent(
                                context, ref, report.eventId!),
                        child: const Text('Concluir evento'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Text('Total de despesas: ',
                    style: Theme.of(context).textTheme.bodyMedium),
                MoneyText(report.totalExpenses),
                const Spacer(),
                if (report.status != 'CLOSED')
                  IconButton(
                    tooltip: 'Compartilhar resumo',
                    onPressed: settlementsAsync.valueOrNull == null
                        ? null
                        : () => _shareReport(
                            report,
                            settlementsAsync.valueOrNull!,
                            // Recebedor escolhido no "Fechar evento".
                            eventAsync.valueOrNull?.receiverNickname,
                            eventAsync.valueOrNull?.receiverUserId),
                    icon: const Icon(Icons.share_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            settlementsAsync.when(
              data: (settlements) => _ReportTable(
                key: ValueKey('${report.eventId}-${report.monthId}'),
                balances: report.balances,
                settlements: settlements,
                canUpdateSettlements: isGroupAdmin,
                isAwaitingPayment: report.status == 'SETTLING',
                isEventOpen: report.status == 'OPEN',
                eventId: report.eventId,
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: LoadingState(),
              ),
              error: (error, _) => ErrorState(
                message: friendlyApiError(error,
                    fallback: 'Não foi possível carregar os pagamentos.'),
                onRetry: () => ref.invalidate(selectedEventSettlementsProvider),
              ),
            ),
          ],
        );
      },
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: friendlyApiError(error,
            fallback: 'Não foi possível carregar o relatório.'),
        onRetry: () => ref.invalidate(selectedEventReportProvider),
      ),
    );
  }
}

class _ReportTable extends ConsumerStatefulWidget {
  const _ReportTable({
    super.key,
    required this.balances,
    required this.settlements,
    required this.canUpdateSettlements,
    required this.isAwaitingPayment,
    required this.isEventOpen,
    required this.eventId,
  });

  final List<MonthlyBalanceModel> balances;
  final List<EventSettlementModel> settlements;
  final bool canUpdateSettlements;

  /// Pago/pendente só pode mudar com o evento aguardando pagamento — aberto
  /// ainda recebe despesa (o saldo muda) e fechado já foi acertado.
  final bool isAwaitingPayment;

  /// Evento aberto ainda recebe despesa: status de pagamento não faz
  /// sentido e fica escondido.
  final bool isEventOpen;
  final String? eventId;

  @override
  ConsumerState<_ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends ConsumerState<_ReportTable> {
  final Set<String> expandedUserIds = {};
  final Map<String, Future<List<BalanceExpenseDetailModel>>> detailsByUser = {};

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
    final semantic = context.semanticColors;
    final settlementsByUser = {
      for (final settlement in widget.settlements)
        settlement.userId: settlement,
    };
    final sortedBalances = [...widget.balances]..sort((first, second) {
        // Quem está acessando vem sempre primeiro.
        final firstIsMe = first.userId == currentUserId;
        final secondIsMe = second.userId == currentUserId;
        if (firstIsMe != secondIsMe) {
          return firstIsMe ? -1 : 1;
        }
        final firstSettlement = settlementsByUser[first.userId];
        final secondSettlement = settlementsByUser[second.userId];
        final statusComparison = _statusOrder(firstSettlement)
            .compareTo(_statusOrder(secondSettlement));
        if (statusComparison != 0) {
          return statusComparison;
        }
        return first.nickname.compareTo(second.nickname);
      });

    // A "Sugestão de pagamentos" saiu daqui: agora é escolhida no "Fechar
    // evento" e chega pra cada um pelo botão "Pagar" / cobrança.
    return _buildRows(
        context, sortedBalances, settlementsByUser, currentUserId, semantic);
  }

  Widget _buildRows(
    BuildContext context,
    List<MonthlyBalanceModel> sortedBalances,
    Map<String, EventSettlementModel> settlementsByUser,
    String? currentUserId,
    dynamic semantic,
  ) {
    return Column(
      children: sortedBalances.map((balance) {
        final settlement = settlementsByUser[balance.userId];
        final expanded = expandedUserIds.contains(balance.userId);
        final isCurrentUser = balance.userId == currentUserId;
        // Pago: fundo neutro + linha esmaecida, pra destacar visualmente
        // quem ainda está pendente.
        final isPaid = !widget.isEventOpen &&
            settlement != null &&
            settlement.amount != 0 &&
            settlement.normalizedStatus == 'PAID';
        final color = isPaid
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : balance.balance < 0
                ? semantic.negative.withValues(alpha: 0.12)
                : balance.balance > 0
                    ? semantic.positive.withValues(alpha: 0.12)
                    : Colors.transparent;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: isPaid ? 0.55 : 1,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: isCurrentUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: isCurrentUser ? 1.5 : 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final toggle = IconButton(
                  tooltip: expanded ? 'Ocultar despesas' : 'Ver despesas',
                  onPressed: () => _toggle(balance.userId),
                  icon: Icon(expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                );
                final name = InkWell(
                  onTap: () => _toggle(balance.userId),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PersonAvatar(
                          name: balance.nickname,
                          seed: balance.userId,
                          radius: 14),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          isCurrentUser ? 'Você' : balance.nickname,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
                final amount = MoneyText(
                  balance.balance,
                  colorBySign: true,
                  showSign: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                );
                final Widget status = widget.isEventOpen
                    ? const SizedBox.shrink()
                    : _SettlementStatus(
                        settlement: settlement,
                        canUpdate: widget.canUpdateSettlements &&
                            widget.isAwaitingPayment,
                        onChanged: (value) =>
                            _updateSettlement(context, ref, settlement!, value),
                      );
                // "Pagar" só na linha de quem está logado, com o evento
                // aguardando pagamento e ainda devendo.
                final payButton = widget.isAwaitingPayment &&
                        isCurrentUser &&
                        settlement != null &&
                        settlement.role == 'DEBTOR' &&
                        settlement.amount != 0 &&
                        settlement.normalizedStatus == 'PENDING' &&
                        widget.eventId != null
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _openPayDialog(context, ref, widget.eventId!),
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('Pagar'),
                        ),
                      )
                    : null;

                // Nome e valor na mesma linha; o status de pagamento vai
                // embaixo, alinhado à direita (evento aberto não tem status).
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: name),
                          const SizedBox(width: AppSpacing.sm),
                          amount,
                          toggle,
                        ],
                      ),
                      if (!widget.isEventOpen)
                        Align(alignment: Alignment.centerRight, child: status),
                      if (payButton != null) ...[
                        const SizedBox(height: 6),
                        payButton,
                      ],
                      if (expanded) _BalanceDetails(details: _details(balance)),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        toggle,
                        Expanded(child: name),
                        SizedBox(
                          width: 110,
                          child: Align(
                              alignment: Alignment.centerRight, child: amount),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 130,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: status,
                          ),
                        ),
                      ],
                    ),
                    if (payButton != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: payButton,
                      ),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.only(left: 48, top: 8),
                        child: _BalanceDetails(details: _details(balance)),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  void _toggle(String userId) {
    setState(() {
      if (!expandedUserIds.add(userId)) {
        expandedUserIds.remove(userId);
      }
    });
  }

  Future<List<BalanceExpenseDetailModel>> _details(
      MonthlyBalanceModel balance) {
    final eventId = ref.read(selectedEventProvider).valueOrNull?.id;
    if (eventId == null) {
      return Future.value([]);
    }
    return detailsByUser.putIfAbsent(
      balance.userId,
      () => ref.read(reportsRepositoryProvider).getBalanceDetails(
            eventId: eventId,
            userId: balance.userId,
          ),
    );
  }
}

/// Mostra o status de pagamento de um participante: um badge simples para
/// quem só pode visualizar, ou um controle editável (só para admin do
/// grupo) quando há saldo de fato para acertar. Quando a pessoa tocou em
/// "Pagar" > "Confirmar pagamento", fica "Pagamento informado" até o admin
/// escolher "Confirmar pagamento" (Pago) ou "Pendente" (volta pra ela).
class _SettlementStatus extends StatelessWidget {
  const _SettlementStatus({
    required this.settlement,
    required this.canUpdate,
    required this.onChanged,
  });

  final EventSettlementModel? settlement;
  final bool canUpdate;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (settlement == null || settlement!.amount == 0) {
      return const StatusBadge(AppStatus.quitado);
    }

    final status = settlement!.normalizedStatus;
    final badge = switch (status) {
      'PAID' => const StatusBadge(AppStatus.confirmado, label: 'Pago'),
      'INFORMED' => const StatusBadge(AppStatus.pagamentoInformado,
          label: 'Pagamento informado'),
      _ => const StatusBadge(AppStatus.pendente),
    };

    if (!canUpdate) {
      return badge;
    }

    return DropdownButton<String>(
      value: status == 'PAID' || status == 'INFORMED' ? status : 'PENDING',
      isDense: true,
      underline: const SizedBox.shrink(),
      selectedItemBuilder: (context) => [
        const StatusBadge(AppStatus.pendente),
        const StatusBadge(AppStatus.confirmado, label: 'Pago'),
        if (status == 'INFORMED') badge,
      ],
      items: [
        const DropdownMenuItem(value: 'PENDING', child: Text('Pendente')),
        const DropdownMenuItem(
            value: 'PAID', child: Text('Confirmar pagamento')),
        // Só aparece como valor atual; o admin não marca "informado".
        if (status == 'INFORMED')
          const DropdownMenuItem(
              value: 'INFORMED',
              enabled: false,
              child: Text('Pagamento informado')),
      ],
      onChanged: (value) {
        if (value != null && value != status) {
          onChanged(value);
        }
      },
    );
  }
}

class _BalanceDetails extends StatelessWidget {
  const _BalanceDetails({required this.details});

  final Future<List<BalanceExpenseDetailModel>> details;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BalanceExpenseDetailModel>>(
      future: details,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              friendlyApiError(snapshot.error!,
                  fallback: 'Não foi possível carregar as despesas.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        final items = [...snapshot.data ?? []]..sort(
            (first, second) => second.expenseDate.compareTo(first.expenseDate));
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Nenhuma despesa encontrada.',
                style: Theme.of(context).textTheme.bodySmall),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: items.map((detail) {
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        _formatDate(detail.expenseDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (detail.installmentLabel != null ||
                              detail.shareLabel != null)
                            Text(
                              [
                                if (detail.installmentLabel != null)
                                  detail.installmentLabel!,
                                if (detail.shareLabel != null)
                                  detail.shareLabel!,
                              ].join(' | '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                          Row(
                            children: [
                              Text('Consumiu ',
                                  style: Theme.of(context).textTheme.bodySmall),
                              MoneyText(detail.consumed,
                                  style: Theme.of(context).textTheme.bodySmall),
                              Text(' | Pagou ',
                                  style: Theme.of(context).textTheme.bodySmall),
                              MoneyText(detail.paid,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    MoneyText(
                      detail.impact,
                      colorBySign: true,
                      showSign: true,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

int _statusOrder(EventSettlementModel? settlement) {
  if (settlement?.normalizedStatus == 'PAID') {
    return 1;
  }
  return 0;
}

/// Compartilha um resumo em texto do relatório (Etapa 11 do roteiro de
/// UX) pelo share sheet nativo — WhatsApp é uma das opções, não a única.
/// Separa "A pagar" e "A receber", com os pendentes primeiro (mesma ordem
/// da tela). Quando o grupo tem recebedor eleito, o texto diz pra quem
/// pagar e o PIX dele; sem recebedor, vai o PIX de cada credor em "A
/// receber".
void _shareReport(
  MonthlyReportModel report,
  List<EventSettlementModel> settlements,
  String? receiverNickname,
  String? receiverUserId,
) {
  final settlementsByUser = {
    for (final settlement in settlements) settlement.userId: settlement,
  };
  int pendingFirst(MonthlyBalanceModel first, MonthlyBalanceModel second) {
    final statusComparison = _statusOrder(settlementsByUser[first.userId])
        .compareTo(_statusOrder(settlementsByUser[second.userId]));
    if (statusComparison != 0) {
      return statusComparison;
    }
    return compareNamesPtBr(first.nickname, second.nickname);
  }

  final debtors = report.balances.where((b) => b.balance < 0).toList()
    ..sort(pendingFirst);
  final creditors = report.balances.where((b) => b.balance > 0).toList()
    ..sort(pendingFirst);
  final title = report.eventName ??
      '${report.month.toString().padLeft(2, '0')}/${report.year}';

  final buffer = StringBuffer()
    ..writeln('$title — ${report.groupName}')
    ..writeln()
    ..writeln('Total de despesas: ${formatCurrencyBRL(report.totalExpenses)}');

  void writeSection(String header, List<MonthlyBalanceModel> balances,
      {bool withPix = false}) {
    if (balances.isEmpty) {
      return;
    }
    buffer
      ..writeln()
      ..writeln(header);
    for (final balance in balances) {
      final settlement = settlementsByUser[balance.userId];
      final isPending = settlement != null &&
          settlement.amount != 0 &&
          settlement.normalizedStatus != 'PAID';
      // Evento aberto ainda não tem pagamento: sai só o valor.
      final statusSuffix = report.status == 'OPEN'
          ? ''
          : isPending
              ? ' (pendente)'
              : ' (pago)';
      // Sem recebedor escolhido, cada credor recebe direto: vai o PIX dele.
      final pix =
          withPix && balance.pixKey != null ? ' — PIX: ${balance.pixKey}' : '';
      buffer.writeln(
          '• ${balance.nickname}: ${formatCurrencyBRL(balance.balance.abs())}$statusSuffix$pix');
    }
  }

  final hasReceiver = receiverNickname != null && receiverNickname.isNotEmpty;
  writeSection('A pagar:', debtors);
  writeSection('A receber:', creditors, withPix: !hasReceiver);

  buffer.writeln();
  if (hasReceiver) {
    final receiverPix = report.balances
        .where((balance) => balance.userId == receiverUserId)
        .map((balance) => balance.pixKey)
        .whereType<String>()
        .firstOrNull;
    buffer.write('Pagamentos devem ser feitos para $receiverNickname');
    buffer.write(receiverPix == null ? '. ' : ' (PIX: $receiverPix). ');
    buffer.write('Consulte o DividiAí para mais detalhes.');
  } else {
    buffer.write(
        'Pagamentos são combinados com o administrador do grupo. Consulte o DividiAí para mais detalhes.');
  }

  SharePlus.instance.share(ShareParams(text: buffer.toString()));
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
                'Não foi possível atualizar o pagamento: ${_errorMessage(error)}')),
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
      return 'apenas administradores do grupo podem alterar pagamentos';
    }
    if (error.message != null) {
      return error.message!;
    }
  }
  return error.toString();
}

/// Enquanto não sabemos o status dos acertos (carregando/erro) trata como
/// pendente — só libera o "Concluir evento" quando confirma que está tudo
/// pago, em vez de deixar tentar e falhar depois.
bool _hasPendingSettlement(
    AsyncValue<List<EventSettlementModel>> settlementsAsync) {
  final settlements = settlementsAsync.valueOrNull;
  if (settlements == null) {
    return true;
  }
  return settlements.any((settlement) =>
      settlement.normalizedStatus == 'PENDING' ||
      settlement.normalizedStatus == 'INFORMED');
}

Future<void> _confirmStartSettlement(
    BuildContext context, WidgetRef ref, String groupId, String eventId) async {
  String? receiverUserId;
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Fechar evento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'A partir de agora não é mais possível adicionar ou editar despesas neste evento. '
                  'Ele fica aguardando pagamento e é concluído sozinho quando todos pagarem. '
                  'Use a tela de Eventos se quiser consolidar o saldo em outro evento antes disso.'),
              const SizedBox(height: 12),
              ReceiverChoice(
                groupId: groupId,
                eventId: eventId,
                onChanged: (value) => receiverUserId = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Fechar evento')),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    await ref
        .read(eventsRepositoryProvider)
        .startSettlement(eventId, receiverUserId: receiverUserId);
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
        const SnackBar(content: Text('Evento fechado, aguardando pagamentos.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível fechar o evento.'))),
      );
    }
  }
}

/// Manda uma notificação in-app pra quem ainda está devendo no evento.
/// Etapa 1 do alerta de cobrança — mensagem genérica; mais pra frente vai
/// puxar a chave PIX de quem recebe (configurável por evento).
Future<void> _sendBillingAlert(
    BuildContext context, WidgetRef ref, String eventId) async {
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Enviar alerta de cobrança'),
      content: const Text(
          'Envia uma notificação no app para quem ainda está com pagamento pendente neste evento. Deseja continuar?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    final recipients =
        await ref.read(eventsRepositoryProvider).sendBillingAlert(eventId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(recipients == 1
                ? 'Alerta enviado para 1 pessoa.'
                : 'Alerta enviado para $recipients pessoas.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível enviar o alerta.'))),
      );
    }
  }
}

Future<void> _confirmCloseEvent(
    BuildContext context, WidgetRef ref, String eventId) async {
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Concluir evento'),
        content: const Text(
            'Depois de concluído, o evento não permite novas alterações. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Concluir')),
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
        const SnackBar(content: Text('Evento concluído com sucesso.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível concluir o evento.'))),
      );
    }
  }
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
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


/// Botão "Pagar": mostra o mesmo texto da notificação de cobrança, com a
/// chave PIX pra copiar. "Confirmar pagamento" deixa o acerto como
/// "Pagamento informado" e avisa os admins do grupo, que confirmam (Pago) ou
/// devolvem pra pendente.
Future<void> _openPayDialog(
    BuildContext context, WidgetRef ref, String eventId) async {
  final repository = ref.read(eventSettlementsRepositoryProvider);
  final MyPaymentModel payment;
  try {
    payment = await repository.myPayment(eventId);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível carregar o pagamento.'))));
    }
    return;
  }
  if (!context.mounted) {
    return;
  }
  // Uma linha por informação: o valor devido; depois, pra cada pessoa a
  // pagar, o valor e o link de copiar o PIX; por último o "Confirmar
  // pagamento". Backend antigo (sem headline) cai no texto corrido.
  final headline = payment.headline ?? payment.message;
  final payees = payment.headline == null ? <PayeeModel>[] : payment.payees;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      Widget copyPix(String pixKey, String receiverName) => Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pixKey));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                      content: Text('Chave PIX de $receiverName copiada.')));
                }
              },
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('Copiar chave PIX'),
            ),
          );

      return AlertDialog(
        title: const Text('Pagamento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (payment.headline != null && payees.isEmpty) ...[
                const SizedBox(height: 12),
                const Text('Combine com o grupo para quem enviar o pagamento.'),
              ],
              for (final payee in payees) ...[
                const SizedBox(height: 12),
                Text(
                    'Pague ${formatCurrencyBRL(payee.amount)} para ${payee.name}.'),
                if (payee.pixKey != null)
                  copyPix(payee.pixKey!, payee.name)
                else
                  Text('${payee.name} não cadastrou chave PIX.',
                      style: Theme.of(dialogContext).textTheme.bodySmall),
              ],
              if (payment.headline == null && payment.pixKey != null) ...[
                const SizedBox(height: 12),
                copyPix(payment.pixKey!, payment.receiverName ?? 'quem recebe'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar pagamento')),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await repository.informPayment(eventId);
    ref.invalidate(selectedEventSettlementsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Pagamento informado. O administrador do grupo vai confirmar.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível confirmar o pagamento.'))));
    }
  }
}
