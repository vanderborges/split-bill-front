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
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/glass_dropdown_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/services/auth_repository.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../events/models/event_model.dart';
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
import '../models/payment_suggestion_model.dart';
import '../services/reports_repository.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      scrollsBehindTopBar: true,
      title: 'Relatórios',
      // Os seletores de grupo/evento ficam sempre visíveis, mesmo sem
      // nenhum relatório ainda — antes ficavam escondidos atrás do estado
      // vazio, e quem não tinha nada cadastrado não via nem a lista de
      // grupos pra navegar.
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16 + topBarInset(context), 16, 16 + bottomBarInset(context)),
        children: const [
          EventFilterFields(),
          SizedBox(height: 16),
          EventBalanceView(),
        ],
      ),
    );
  }
}

/// Filtros Grupo + Evento do Relatório e do Extrato: gravam a escolha nos
/// providers globais (grupo/evento selecionados).
/// Extrato com "Todos os eventos" escolhido (um card por evento).
final statementAllEventsProvider = StateProvider<bool>((ref) => false);

class EventFilterFields extends ConsumerWidget {
  const EventFilterFields({super.key, this.allowAllEvents = false});

  /// Extrato: o seletor de evento ganha "Todos os eventos"
  /// ([statementAllEventsProvider]).
  final bool allowAllEvents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Extrato: inclui os grupos/eventos de onde a pessoa saiu (só leitura).
    final statement = allowAllEvents;
    final eventAsync = ref.watch(
        statement ? statementSelectedEventProvider : selectedEventProvider);
    final eventsAsync =
        ref.watch(statement ? statementEventsProvider : eventsProvider);
    final groupsAsync =
        ref.watch(statement ? allGroupsProvider : groupsProvider);
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final allEvents = allowAllEvents && ref.watch(statementAllEventsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        groupsAsync.when(
          data: (groups) => GlassDropdownField<String?>(
            initialValue: selectedGroupId,
            decoration: const InputDecoration(labelText: 'Grupo'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Todos os grupos')),
              ...groups.map((group) => DropdownMenuItem<String?>(
                  value: group.id,
                  child: Text(group.viewerRemoved
                      ? '${group.name} (você saiu)'
                      : group.name))),
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
                    key: ValueKey(allEvents ? null : event?.id),
                    events: events,
                    selectedId: allEvents ? null : event?.id,
                    allEventsLabel: allowAllEvents ? 'Todos os eventos' : null,
                    sortByGroup: allowAllEvents,
                    // Extrato: "Grupo | Evento" só com "Todos os grupos"; com um
                    // grupo escolhido, só o nome do evento.
                    showGroupName: !allowAllEvents || selectedGroupId == null,
                    groupNameOf: (groupId) =>
                        _groupName(groupsAsync.valueOrNull, groupId),
                    onChanged: (value) {
                      if (allowAllEvents) {
                        ref.read(statementAllEventsProvider.notifier).state =
                            value == null;
                      }
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
      ],
    );
  }
}

/// Saldo do evento selecionado: status, ações do evento (Fechar, cobrança,
/// Concluir), compartilhar, total e os cards de saldo com pagamento. Usado
/// no Relatório e na visão "Saldo" da tela de Despesas.
///
/// [onlyCurrentUser] (tela Extrato): só o card de quem está logado, sem as
/// ações do evento nem o compartilhar.
class EventBalanceView extends ConsumerWidget {
  const EventBalanceView({super.key, this.onlyCurrentUser = false});

  final bool onlyCurrentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Extrato: o evento vem da lista do Extrato (inclui os de grupos de
    // onde a pessoa saiu) e o saldo/pagamentos são buscados por evento.
    final eventAsync = ref.watch(onlyCurrentUser
        ? statementSelectedEventProvider
        : selectedEventProvider);
    final statementEvent = eventAsync.valueOrNull;
    final AsyncValue<MonthlyReportModel?> reportAsync = !onlyCurrentUser
        ? ref.watch(selectedEventReportProvider)
        : statementEvent == null
            ? (eventAsync.isLoading
                ? const AsyncLoading<MonthlyReportModel?>()
                : const AsyncData<MonthlyReportModel?>(null))
            : ref
                .watch(eventReportProvider(statementEvent.id))
                .whenData<MonthlyReportModel?>((report) => report);
    final AsyncValue<List<EventSettlementModel>> settlementsAsync =
        !onlyCurrentUser
            ? ref.watch(selectedEventSettlementsProvider)
            : statementEvent == null
                ? const AsyncData(<EventSettlementModel>[])
                : ref.watch(eventSettlementsProvider(statementEvent.id));
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
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
        final hasActions = !onlyCurrentUser &&
            isGroupAdmin &&
            (report.status == 'OPEN' || report.status == 'SETTLING');
        final balances = onlyCurrentUser
            ? report.balances
                .where((balance) => balance.includes(currentUserId))
                .toList()
            : report.balances;
        if (onlyCurrentUser && balances.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Você não tem saldo neste evento.',
            message: 'Escolha outro evento ou veja o Extrato geral.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasActions) ...[
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  // "Fechar evento" fica do lado direito da tela.
                  alignment: report.status == 'OPEN'
                      ? WrapAlignment.end
                      : WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (report.status == 'OPEN' && isGroupAdmin)
                      FilledButton(
                        onPressed: report.eventId == null
                            ? null
                            : () => confirmStartSettlement(
                                context, ref, report.groupId, report.eventId!),
                        child: const Text('Fechar evento'),
                      ),
                    if (report.status == 'SETTLING' && isGroupAdmin)
                      OutlinedButton.icon(
                        onPressed: report.eventId == null
                            ? null
                            : () => _sendBillingAlert(
                                context, ref, report.eventId!),
                        icon: const Icon(Icons.campaign_outlined),
                        label: const Text('Enviar alerta de cobrança'),
                      ),
                    // Habilitado com o evento aguardando pagamentos, mesmo com
                    // pagamento em aberto: confirmar marca todos como pagos.
                    if (report.status == 'SETTLING' && isGroupAdmin)
                      FilledButton(
                        onPressed: report.eventId == null
                            ? null
                            : () => _confirmCloseEvent(
                                context, ref, report.eventId!),
                        child: const Text('Concluir evento'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Extrato não mostra o total de despesas do evento.
            if (!onlyCurrentUser) ...[
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
            ],
            settlementsAsync.when(
              data: (settlements) => _ReportTable(
                key: ValueKey('${report.eventId}-${report.monthId}'),
                balances: balances,
                settlements: settlements,
                canUpdateSettlements: isGroupAdmin,
                isAwaitingPayment: report.status == 'SETTLING',
                receiverUserId: eventAsync.valueOrNull?.receiverUserId,
                isEventOpen: report.status == 'OPEN',
                eventId: report.eventId,
                // Extrato: "Grupo | Evento" acima do nome.
                header: onlyCurrentUser
                    ? '${report.groupName} | ${report.eventName ?? '${report.month.toString().padLeft(2, '0')}/${report.year}'}'
                    : null,
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
    this.receiverUserId,
    this.header,
  });

  /// Quem recebe os pagamentos do evento: já fica "Pago" (backend) e o
  /// status dele não muda.
  final String? receiverUserId;

  /// Extrato: linha pequena "Grupo | Evento" no topo do card, acima do
  /// nome.
  final String? header;

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

  /// Quem paga quanto pra quem (evento aguardando pagamentos) - o
  /// informativo do card aberto. Carrega na primeira vez que abre um card.
  Future<List<PaymentSuggestionModel>>? _suggestionsFuture;

  @override
  void didUpdateWidget(_ReportTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Saldos recarregados (pagamento alterado, recebedor): busca de novo.
    if (!identical(oldWidget.balances, widget.balances)) {
      _suggestionsFuture = null;
    }
  }

  Future<List<PaymentSuggestionModel>>? _suggestions() {
    final eventId = widget.eventId;
    if (!widget.isAwaitingPayment || eventId == null) {
      return null;
    }
    return _suggestionsFuture ??=
        ref.read(reportsRepositoryProvider).getPaymentSuggestions(eventId);
  }

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
        final firstIsMe = first.includes(currentUserId);
        final secondIsMe = second.includes(currentUserId);
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
        // Quem é vinculado ao titular (gasto agrupado) também vê a linha
        // como "Você".
        final isCurrentUser = balance.includes(currentUserId);
        // Pago: fundo neutro + linha esmaecida, pra destacar visualmente
        // quem ainda está pendente. Aberto, o card pago fica igual ao
        // pendente; ao fechar volta a esmaecer. A seta de abrir nunca
        // esmaece (mesma cor do card pendente).
        final isPaid = !widget.isEventOpen &&
            settlement != null &&
            settlement.amount != 0 &&
            settlement.normalizedStatus == 'PAID';
        final dimmed = isPaid && !expanded;
        Widget fade(Widget child) => AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: dimmed ? 0.55 : 1,
              child: child,
            );
        final color = dimmed
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.55)
            : balance.balance < 0
                ? semantic.negative.withValues(alpha: 0.12)
                : balance.balance > 0
                    ? semantic.positive.withValues(alpha: 0.12)
                    : Colors.transparent;
        final borderColor = isCurrentUser
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).dividerColor;
        // Evento aguardando pagamentos, card aberto: quem paga quanto pra
        // quem, à esquerda, na altura do status.
        final suggestions = expanded ? _suggestions() : null;
        final Widget? hint = suggestions == null
            ? null
            : FutureBuilder<List<PaymentSuggestionModel>>(
                future: suggestions,
                builder: (context, snapshot) => _PaymentHint(
                  userId: balance.userId,
                  myUserId: widget.balances
                      .where((item) => item.includes(currentUserId))
                      .firstOrNull
                      ?.userId,
                  suggestions: snapshot.data ?? const [],
                ),
              );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: dimmed
                  ? borderColor.withValues(alpha: borderColor.a * 0.55)
                  : borderColor,
              width: isCurrentUser ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.header != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: fade(Text(
                    widget.header!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 430;
                  final toggle = IconButton(
                    tooltip: expanded ? 'Ocultar despesas' : 'Ver despesas',
                    onPressed: () => _toggle(balance.userId),
                    icon: Icon(expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down),
                  );
                  final name = fade(InkWell(
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
                            isCurrentUser
                                ? _youLabel(balance, currentUserId)
                                : _groupedLabel(balance),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ));
                  final amount = fade(MoneyText(
                    balance.balance,
                    colorBySign: true,
                    showSign: true,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ));
                  final Widget status = widget.isEventOpen
                      ? const SizedBox.shrink()
                      : fade(_SettlementStatus(
                          settlement: settlement,
                          canUpdate: widget.canUpdateSettlements &&
                              widget.isAwaitingPayment &&
                              settlement?.userId != widget.receiverUserId,
                          onChanged: (value) => _updateSettlement(
                              context, ref, settlement!, value),
                        ));
                  // Quem recebe os pagamentos do evento (aguardando
                  // pagamentos) repassa o crédito de quem ficou positivo:
                  // link discreto pra copiar o PIX dessa pessoa.
                  final pixKey = balance.pixKey;
                  final Widget? pixLink = widget.isAwaitingPayment &&
                          widget.receiverUserId != null &&
                          widget.receiverUserId == currentUserId &&
                          !isCurrentUser &&
                          balance.balance > 0 &&
                          pixKey != null &&
                          pixKey.isNotEmpty
                      ? _CopyPixLink(pixKey: pixKey, name: balance.nickname)
                      : null;
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
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hint != null) hint,
                                    if (pixLink != null) pixLink,
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              status,
                            ],
                          ),
                        if (payButton != null) ...[
                          const SizedBox(height: 6),
                          payButton,
                        ],
                        if (expanded) _detailsWidget(balance, currentUserId),
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
                                alignment: Alignment.centerRight,
                                child: amount),
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
                      if (hint != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 48, top: 4),
                          child: Align(
                              alignment: Alignment.centerLeft, child: hint),
                        ),
                      if (pixLink != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 48),
                          child: Align(
                              alignment: Alignment.centerLeft, child: pixLink),
                        ),
                      if (payButton != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: payButton,
                        ),
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.only(left: 48, top: 8),
                          child: _detailsWidget(balance, currentUserId),
                        ),
                    ],
                  );
                },
              ),
            ],
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

  /// Gasto agrupado (cobrança vinculada): "Você + Fulano"; sem mais
  /// ninguém com gasto no evento, só "Você".
  String _youLabel(MonthlyBalanceModel balance, String? currentUserId) {
    final others = balance.activeMembers
        .where((member) => member.userId != currentUserId)
        .map((member) => member.nickname)
        .toList();
    return others.isEmpty ? 'Você' : 'Você + ${others.join(' + ')}';
  }

  /// Card de outra pessoa com gasto agrupado: só quem tem gasto no evento
  /// ("Fulano + Ciclano"); backend antigo cai no nome que veio.
  String _groupedLabel(MonthlyBalanceModel balance) {
    final members = balance.activeMembers;
    return members.length < 2
        ? balance.nickname
        : members.map((member) => member.nickname).join(' + ');
  }

  /// Despesas da linha aberta. Com gasto agrupado (Extrato, Saldo e
  /// Relatório), separa por pessoa: quem está logado primeiro ("Você"), cada
  /// um com o total só dele e a lista, com uma linha entre eles.
  Widget _detailsWidget(MonthlyBalanceModel balance, String? currentUserId) {
    final members = balance.activeMembers;
    if (members.length < 2) {
      return _BalanceDetails(details: _details(balance));
    }
    final ordered = [
      ...members.where((member) => member.userId == currentUserId),
      ...members.where((member) => member.userId != currentUserId),
    ];
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final member in ordered) ...[
          // Linha separando um participante do outro.
          if (member != ordered.first)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Divider(height: 1),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    member.userId == currentUserId ? 'Você' : member.nickname,
                    style: textTheme.titleSmall,
                  ),
                ),
                MoneyText(member.balance, colorBySign: true, showSign: true),
              ],
            ),
          ),
          _BalanceDetails(
              details: _memberDetails(member.userId, singleUser: true)),
        ],
      ],
    );
  }

  Future<List<BalanceExpenseDetailModel>> _memberDetails(String userId,
      {required bool singleUser}) {
    final eventId =
        widget.eventId ?? ref.read(selectedEventProvider).valueOrNull?.id;
    if (eventId == null) {
      return Future.value([]);
    }
    return detailsByUser.putIfAbsent(
      '$userId|$singleUser',
      () => ref.read(reportsRepositoryProvider).getBalanceDetails(
            eventId: eventId,
            userId: userId,
            onlyUser: singleUser,
          ),
    );
  }

  Future<List<BalanceExpenseDetailModel>> _details(
      MonthlyBalanceModel balance) {
    final eventId =
        widget.eventId ?? ref.read(selectedEventProvider).valueOrNull?.id;
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

    // Opções do admin: pendente só vira "Pago"; informado pode ser
    // confirmado (Pago) ou devolvido (Pendente); pago pode voltar a
    // pendente.
    final options = switch (status) {
      'PAID' => const [('PENDING', 'Pendente')],
      'INFORMED' => const [('PAID', 'Pago'), ('PENDING', 'Pendente')],
      _ => const [('PAID', 'Pago')],
    };

    return Builder(
      builder: (buttonContext) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => _openMenu(buttonContext, options),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  /// Mesmo padrão das listas dos campos de seleção: abre logo abaixo, no
  /// vidro dos menus, cada opção numa linha só (sem quebrar).
  Future<void> _openMenu(
      BuildContext context, List<(String, String)> options) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) {
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    const width = 180.0;
    // Alinhado pela direita do status (ele fica no canto do card).
    final left = topLeft.dx + box.size.width - width;
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
            left < 8 ? 8 : left, topLeft.dy + box.size.height + 4, width, 0),
        Offset.zero & overlay.size,
      ),
      color: glassMenuColor(context),
      shape: const RoundedRectangleBorder(borderRadius: glassMenuRadius),
      constraints: const BoxConstraints(minWidth: width, maxWidth: width),
      items: [
        for (final (value, label) in options)
          PopupMenuItem<String>(
            value: value,
            height: kMinInteractiveDimension,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
    if (picked != null && picked != settlement!.normalizedStatus) {
      onChanged(picked);
    }
  }
}

/// Informativo do card aberto com o evento aguardando pagamentos, em
/// itálico: quanto a pessoa deve pagar e pra quem; com saldo positivo, quem
/// deve pagar pra ela.
class _PaymentHint extends StatelessWidget {
  const _PaymentHint({
    required this.userId,
    required this.myUserId,
    required this.suggestions,
  });

  /// Pessoa do card (titular, no gasto agrupado).
  final String userId;

  /// Card de quem está logado (titular do gasto agrupado dele), pra
  /// escrever "Você"/"você".
  final String? myUserId;
  final List<PaymentSuggestionModel> suggestions;

  @override
  Widget build(BuildContext context) {
    final mine = suggestions
        .where((item) => item.fromUserId == userId || item.toUserId == userId)
        .toList();
    if (mine.isEmpty) {
      return const SizedBox.shrink();
    }
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSurfaceVariant);
    String subject(String id, String nickname) =>
        id == myUserId ? 'Você' : nickname;
    String target(String id, String nickname) =>
        id == myUserId ? 'você' : nickname;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in mine)
          Text(
            '${subject(item.fromUserId, item.fromNickname)} deve pagar '
            '${formatCurrencyBRL(item.amount)} para '
            '${target(item.toUserId, item.toNickname)}',
            style: style,
          ),
      ],
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
/// Separa "A pagar" e "A receber", em ordem alfabética e sem status de
/// pagamento. Quando o grupo tem recebedor eleito, o texto diz pra quem
/// pagar e o PIX dele. A lista de pessoas não leva chave PIX.
void _shareReport(
  MonthlyReportModel report,
  List<EventSettlementModel> settlements,
  String? receiverNickname,
  String? receiverUserId,
) {
  int byName(MonthlyBalanceModel first, MonthlyBalanceModel second) =>
      compareNamesPtBr(first.nickname, second.nickname);

  final debtors = report.balances.where((b) => b.balance < 0).toList()
    ..sort(byName);
  final creditors = report.balances.where((b) => b.balance > 0).toList()
    ..sort(byName);
  final title = report.eventName ??
      '${report.month.toString().padLeft(2, '0')}/${report.year}';

  final buffer = StringBuffer()
    ..writeln('$title — ${report.groupName}')
    ..writeln()
    ..writeln('Total de despesas: ${formatCurrencyBRL(report.totalExpenses)}');

  void writeSection(String header, List<MonthlyBalanceModel> balances) {
    if (balances.isEmpty) {
      return;
    }
    buffer
      ..writeln()
      ..writeln(header);
    // Só nome e valor, sem status de pagamento.
    for (final balance in balances) {
      buffer.writeln(
          '• ${balance.nickname}: ${formatCurrencyBRL(balance.balance.abs())}');
    }
  }

  final hasReceiver = receiverNickname != null && receiverNickname.isNotEmpty;
  writeSection('A pagar:', debtors);
  writeSection('A receber:', creditors);

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
    // O último pagamento confirmado conclui o evento no backend: recarrega
    // também o evento, pra o status mudar na tela sem precisar atualizar.
    _refreshEventScreens(ref);
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

/// Recarrega o evento selecionado (status no seletor, saldo, pagamentos,
/// despesas) e a Home depois de uma mudança que pode mexer no status do
/// evento. Sem evento escolhido explicitamente, fixa o que está na tela —
/// senão, ao concluir, o padrão pulava pra outro evento ainda aberto.
void _refreshEventScreens(WidgetRef ref) {
  final current = ref.read(selectedEventProvider).valueOrNull;
  if (current != null && ref.read(selectedEventIdProvider) == null) {
    ref.read(selectedEventIdProvider.notifier).state = current.id;
  }
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
  ref.invalidate(eventReportProvider);
  ref.invalidate(eventSettlementsProvider);
  ref.invalidate(statementEventsProvider);
}

/// "Fechar evento" (admin): escolhe quem recebe e abre o evento para
/// pagamento. Usado no Saldo/Relatório e no menu do evento em Eventos.
Future<void> confirmStartSettlement(
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
                  'Ele fica aguardando pagamentos e é concluído sozinho quando todos pagarem.'),
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
            'Todos os pagamentos deste evento serão marcados como pagos e o evento será fechado. '
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
    await ref.read(eventsRepositoryProvider).close(eventId, markAllPaid: true);
    _refreshEventScreens(ref);
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
    ref.invalidate(eventSettlementsProvider(eventId));
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

/// Extrato com "Todos os eventos": um card de quem está logado por evento
/// (do grupo filtrado, ou de todos), do mês mais recente pro mais antigo —
/// evento avulso usa a data de criação. Cada card tem o nome do evento e,
/// discreto, o do grupo; evento em que a pessoa não tem saldo não aparece.
class AllEventsStatementView extends ConsumerWidget {
  const AllEventsStatementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Inclui os eventos com despesa da pessoa em grupos de onde ela saiu.
    final eventsAsync = ref.watch(statementEventsProvider);
    final groups = ref.watch(allGroupsProvider).valueOrNull;
    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nenhum evento para mostrar.',
            message: 'Crie um evento ou escolha outro grupo.',
          );
        }
        final sorted = [...events]..sort((a, b) {
            final byDate = b.sortDate.compareTo(a.sortDate);
            if (byDate != 0) {
              return byDate;
            }
            return (b.createdAt ?? DateTime(0))
                .compareTo(a.createdAt ?? DateTime(0));
          });
        return Column(
          children: [
            for (final event in sorted)
              _MyEventBalanceCard(
                key: ValueKey(event.id),
                event: event,
                groupName: _groupName(groups, event.groupId),
              ),
          ],
        );
      },
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: friendlyApiError(error,
            fallback: 'Não foi possível carregar os eventos.'),
        onRetry: () => ref.invalidate(eventsProvider),
      ),
    );
  }
}

class _MyEventBalanceCard extends ConsumerWidget {
  const _MyEventBalanceCard({
    super.key,
    required this.event,
    required this.groupName,
  });

  final EventModel event;
  final String groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(eventReportProvider(event.id));
    final settlementsAsync = ref.watch(eventSettlementsProvider(event.id));
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
    final isGroupAdmin =
        ref.watch(groupRoleProvider(event.groupId)).valueOrNull == 'ADMIN';
    final report = reportAsync.valueOrNull;
    final settlements = settlementsAsync.valueOrNull;
    if (reportAsync.hasError || settlementsAsync.hasError) {
      return const SizedBox.shrink();
    }
    if (report == null || settlements == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: LinearProgressIndicator(),
      );
    }
    final mine =
        report.balances.where((b) => b.includes(currentUserId)).toList();
    if (mine.isEmpty) {
      return const SizedBox.shrink();
    }
    return _ReportTable(
      balances: mine,
      settlements: settlements,
      canUpdateSettlements: isGroupAdmin,
      isAwaitingPayment: report.status == 'SETTLING',
      receiverUserId: event.receiverUserId,
      isEventOpen: report.status == 'OPEN',
      eventId: event.id,
      header: '$groupName | ${event.name}',
    );
  }
}

/// Link discreto "Copiar chave PIX" no card de quem tem crédito, só pra
/// quem recebe os pagamentos do evento (repassa o valor pra essa pessoa).
class _CopyPixLink extends StatelessWidget {
  const _CopyPixLink({required this.pixKey, required this.name});

  final String pixKey;
  final String name;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: pixKey));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Chave PIX de $name copiada.')));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_outlined, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'Copiar chave PIX',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color, decoration: TextDecoration.underline),
            ),
          ],
        ),
      ),
    );
  }
}
