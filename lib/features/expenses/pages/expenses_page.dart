import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/navigation_history.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/api_error.dart';
import '../../../shared/ptbr_sort.dart';
import '../../../shared/widgets/amount_field.dart';
import '../../../shared/widgets/keyboard_done_bar.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/glass_dropdown_field.dart';
import '../../../shared/widgets/auto_collapsing_fab.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/pinned_header.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../auth/services/auth_repository.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../events/models/event_model.dart';
import '../../events/services/events_repository.dart';
import '../../events/services/new_event_intent.dart';
import '../../events/widgets/event_picker_field.dart';
import '../../groups/models/group_model.dart';
import '../../groups/services/groups_repository.dart';
import '../../groups/services/create_group_intent.dart';
import '../../reports/pages/reports_page.dart';
import '../../reports/services/reports_repository.dart';
import '../../users/models/user_option_model.dart';
import '../models/expense_model.dart';
import '../services/expense_categories_repository.dart';
import '../services/expenses_repository.dart';

/// Tela de Despesas. [openBalance] (rota `/expenses?view=saldo`, usada
/// pelo "Ver saldo" do evento e pelo toque nas notificações) abre direto na
/// visão "Saldo".
class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key, this.openBalance = false});

  final bool openBalance;

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  @override
  void initState() {
    super.initState();
    if (widget.openBalance) {
      ref.read(showEventBalanceProvider.notifier).state = true;
    }
  }

  @override
  void didUpdateWidget(covariant ExpensesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openBalance && !oldWidget.openBalance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(showEventBalanceProvider.notifier).state = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => const _ExpensesView();
}

class _ExpensesView extends ConsumerWidget {
  const _ExpensesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(selectedEventProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final expensesAsync = ref.watch(selectedEventExpensesProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final showOnlyMine = ref.watch(showOnlyMyExpensesProvider);
    final showBalance = ref.watch(showEventBalanceProvider);

    // Evento selecionado que não está aberto (aguardando pagamento ou
    // fechado) não aceita despesa — nem mostra o botão.
    final selectedEventClosedForExpenses =
        eventAsync.valueOrNull?.isOpen == false;
    // Título = nome do grupo do evento selecionado.
    final selectedEvent = eventAsync.valueOrNull;
    final title = selectedEvent == null
        ? 'Despesas'
        : _groupName(groupsAsync.valueOrNull, selectedEvent.groupId);

    return AppScaffold(
      title: title,
      // Despesas/Saldo de um evento: a seta volta pra lista de Eventos.
      onBack: () => goBack(context, fallback: '/events'),
      // Evento e Despesas/Saldo fixos no topo; a lista rola por trás.
      scrollsBehindTopBar: true,
      // "+" também no Saldo (evento aberto).
      floatingActionButton: selectedEventClosedForExpenses
          ? null
          : AutoCollapsingFab(
              label: 'Nova despesa',
              onPressed: () =>
                  openNewExpenseFlow(context, ref, useSelectedEvent: true),
            ),
      child: eventAsync.when(
        data: (event) {
          if (event == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => openNewExpenseFlow(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar despesa'),
              ),
            );
          }
          final isGroupAdmin =
              ref.watch(groupRoleProvider(event.groupId)).valueOrNull ==
                  'ADMIN';

          return PinnedHeaderLayout(
              // Seletor de Evento e Despesas/Saldo fixos (fundo desfocado).
              header: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  eventsAsync.when(
                    data: (allEvents) {
                      // Lista todos os eventos do grupo (não só os abertos) —
                      // senão, ao sair de um evento fechado/aguardando
                      // pagamento ele some do seletor e não dá pra voltar.
                      // Quem controla se dá pra ADICIONAR despesa é o status
                      // do evento selecionado, não essa lista.
                      final items = [...allEvents];
                      if (items.every((item) => item.id != event.id)) {
                        items.add(event);
                      }
                      return EventPickerField(
                        // Muda a key ao trocar de evento por fora (ex.: toque
                        // numa notificação) pra o campo pegar o novo valor.
                        key: ValueKey(event.id),
                        events: items,
                        selectedId: event.id,
                        // Só o nome do evento (pedido do usuário).
                        showGroupName: false,
                        groupNameOf: (groupId) =>
                            _groupName(groupsAsync.valueOrNull, groupId),
                        onChanged: (value) {
                          final picked =
                              items.where((item) => item.id == value);
                          if (picked.isNotEmpty) {
                            selectEvent(ref,
                                groupId: picked.first.groupId, eventId: value);
                          }
                          ref.invalidate(selectedEventProvider);
                          ref.invalidate(selectedEventExpensesProvider);
                        },
                      );
                    },
                    loading: () => Text('Evento ${event.name}',
                        style: Theme.of(context).textTheme.titleMedium),
                    error: (_, __) => Text('Evento ${event.name}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: false,
                            icon: Icon(Icons.receipt_long_outlined),
                            label: Text('Despesas')),
                        ButtonSegment(
                            value: true,
                            icon: Icon(Icons.account_balance_wallet_outlined),
                            label: Text('Saldo')),
                      ],
                      selected: {showBalance},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) => ref
                          .read(showEventBalanceProvider.notifier)
                          .state = selection.first,
                    ),
                  ),
                ],
              ),
              builder: (context, top) => CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: SizedBox(height: top)),
                      // "Mostrar só minhas despesas" rola junto com a lista.
                      if (!showBalance)
                        SliverToBoxAdapter(
                            child: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.lg),
                          child: Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  value: showOnlyMine,
                                  onChanged: (value) => ref
                                      .read(showOnlyMyExpensesProvider.notifier)
                                      .state = value ?? false,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg),
                                  title:
                                      const Text('Mostrar só minhas despesas'),
                                ),
                              ),
                            ],
                          ),
                        )),
                      // Saldo: o mesmo conteúdo do Relatório (ações do evento,
                      // pagamento, compartilhar e os cards de saldo).
                      if (showBalance)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg,
                              fabClearance + bottomBarInset(context)),
                          sliver: const SliverToBoxAdapter(
                              child: EventBalanceView()),
                        ),
                      if (!showBalance)
                        expensesAsync.when(
                          data: (expenses) {
                            final visibleExpenses = showOnlyMine
                                ? expenses
                                    .where((expense) => _isUserInvolved(
                                        expense, currentUser?.id))
                                    .toList()
                                : expenses;
                            if (visibleExpenses.isEmpty) {
                              return SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: EmptyState(
                                    icon: Icons.receipt_long_outlined,
                                    title: showOnlyMine
                                        ? 'Você não participa de nenhuma despesa deste evento.'
                                        : 'Nenhuma despesa cadastrada.',
                                    message: showOnlyMine
                                        ? 'Desmarque o filtro para ver as despesas de todo o grupo.'
                                        : selectedEventClosedForExpenses
                                            // Fechado não tem o "+".
                                            ? 'Este evento não recebe mais despesas.'
                                            : 'Toque em "+" para registrar o primeiro gasto deste evento.',
                                  ));
                            }
                            final sortedExpenses = [...visibleExpenses]
                              ..sort((first, second) {
                                final dateComparison = second.expenseDate
                                    .compareTo(first.expenseDate);
                                if (dateComparison != 0) {
                                  return dateComparison;
                                }
                                return second.createdAt
                                    .compareTo(first.createdAt);
                              });
                            return SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.sm,
                                    AppSpacing.lg,
                                    fabClearance + bottomBarInset(context)),
                                sliver: SliverList.separated(
                                  itemCount: sortedExpenses.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final expense = sortedExpenses[index];
                                    final canChange = _canChangeExpense(
                                      expense,
                                      currentUser?.id,
                                      isGroupAdmin,
                                    );
                                    final shareSummary =
                                        _expenseShareSummary(expense);
                                    final installmentLabel =
                                        expense.installmentLabel;
                                    return ListTile(
                                      leading: SizedBox(
                                        width: 64,
                                        child: Text(
                                          _formatDateShort(expense.expenseDate),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.visible,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                      onTap: () async {
                                        // Sempre abre o detalhe enxuto primeiro; o
                                        // formulário completo só vem pelo "Editar".
                                        final wantsEdit =
                                            await _openExpenseDetails(
                                                context, expense,
                                                canEdit:
                                                    canChange && event.isOpen);
                                        if (!wantsEdit || !context.mounted) {
                                          return;
                                        }
                                        final users = await _loadEventUsers(
                                            ref, event.groupId,
                                            eventId: event.id,
                                            keepUserIds: {
                                              ...expense.participants.map(
                                                  (participant) =>
                                                      participant.userId),
                                              ...expense.payers
                                                  .map((payer) => payer.userId),
                                            });
                                        final categories =
                                            await _loadCategoryNames(ref);
                                        if (context.mounted) {
                                          await _openExpenseForm(context, ref,
                                              event, users, categories,
                                              expense: expense);
                                        }
                                      },
                                      title: Text(expense.description),
                                      subtitle: [shareSummary, installmentLabel]
                                              .whereType<String>()
                                              .isEmpty
                                          ? null
                                          : Text([
                                              shareSummary,
                                              installmentLabel
                                            ].whereType<String>().join(' | ')),
                                      trailing: showOnlyMine
                                          ? _UserBalanceText(_userBalance(
                                              expense, currentUser?.id))
                                          : MoneyText(expense.amount),
                                    );
                                  },
                                ));
                          },
                          loading: () => const SliverFillRemaining(
                              hasScrollBody: false, child: LoadingState()),
                          error: (error, _) => SliverFillRemaining(
                              hasScrollBody: false,
                              child: ErrorState(
                                message: friendlyApiError(error,
                                    fallback:
                                        'Não foi possível carregar as despesas.'),
                                onRetry: () => ref
                                    .invalidate(selectedEventExpensesProvider),
                              )),
                        ),
                    ],
                  ));
        },
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyApiError(error,
              fallback: 'Não foi possível carregar o evento.'),
          onRetry: () => ref.invalidate(selectedEventProvider),
        ),
      ),
    );
  }
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

bool _canChangeExpense(
  ExpenseModel expense,
  String? currentUserId,
  bool isGroupAdmin,
) {
  return isGroupAdmin || expense.createdByUserId == currentUserId;
}

/// Usado pelo filtro "Mostrar só minhas despesas": considera o usuário
/// envolvido se ele pagou (pagador único ou em uma divisão de pagadores)
/// ou se está entre os participantes que consomem a despesa.
bool _isUserInvolved(ExpenseModel expense, String? userId) {
  if (userId == null) {
    return false;
  }
  return expense.payerId == userId ||
      expense.payers.any((payer) => payer.userId == userId) ||
      expense.participants.any((participant) => participant.userId == userId);
}

/// Saldo do usuário numa despesa: quanto pagou menos a parte que consumiu.
/// Positivo = tem a receber, negativo = deve.
double _userBalance(ExpenseModel expense, String? userId) {
  if (userId == null) {
    return 0;
  }
  final paid = expense.payers.isEmpty
      ? (expense.payerId == userId ? expense.amount : 0.0)
      : expense.payers
          .where((payer) => payer.userId == userId)
          .fold<double>(0.0, (total, payer) => total + payer.amount);
  final consumed = expense.participants
      .where((participant) => participant.userId == userId)
      .fold<double>(
          0.0, (total, participant) => total + participant.shareAmount);
  return paid - consumed;
}

/// Saldo com sinal: verde quando positivo ou zero, vermelho quando negativo.
class _UserBalanceText extends StatelessWidget {
  const _UserBalanceText(this.balance);

  final double balance;

  @override
  Widget build(BuildContext context) {
    // Arredonda em centavos pra "-0,00" de resto de divisão não virar
    // vermelho.
    final value = (balance * 100).round() / 100;
    final semantic = context.semanticColors;
    return MoneyText(
      value,
      showSign: true,
      style: Theme.of(context)
          .textTheme
          .bodyLarge
          ?.copyWith(color: value < 0 ? semantic.negative : semantic.positive),
    );
  }
}

Future<void> _deleteExpense(
    BuildContext context, WidgetRef ref, ExpenseModel expense) async {
  try {
    await ref.read(expensesRepositoryProvider).delete(expense.id);
    ref.invalidate(selectedEventExpensesProvider);
    ref.invalidate(selectedEventReportProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível excluir a despesa.'))),
      );
    }
  }
}

Future<bool> _confirmDeleteExpense(
  BuildContext context,
  WidgetRef ref,
  ExpenseModel expense,
) async {
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Excluir despesa'),
        content: Text('Deseja excluir "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      );
    },
  );

  if (confirmed == true && context.mounted) {
    await _deleteExpense(context, ref, expense);
    return true;
  }
  return false;
}

/// Finaliza a assinatura a partir do mês corrente — a despesa deste mês
/// continua existindo, só para de gerar a próxima automaticamente.
Future<bool> _confirmCancelSubscription(
  BuildContext context,
  WidgetRef ref,
  ExpenseModel expense,
) async {
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Finalizar assinatura'),
      content: Text(
          'A partir do mês que vem, "${expense.description}" não vai mais ser lançada automaticamente. A despesa deste mês continua normal. Deseja continuar?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finalizar')),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return false;
  }
  try {
    await ref.read(expensesRepositoryProvider).cancelSubscription(expense.id);
    ref.invalidate(currentMonthExpensesProvider);
    ref.invalidate(selectedEventExpensesProvider);
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível finalizar a assinatura.'))),
      );
    }
    return false;
  }
}

/// Fluxo único de "adicionar despesa" — usado pelo FAB e pelo botão de
/// estado vazio da tela de Despesas e pelo CTA "Nova despesa" da Home. O
/// formulário abre por cima da tela de onde veio (da Home, volta pra Home).
///
/// Com [useSelectedEvent] (FAB da tela de Despesas) e o evento da tela
/// aberto, vai direto pro formulário nesse evento. Senão abre um menu pra
/// escolher grupo e evento (pré-selecionados com o que está na tela); com
/// só 1 grupo e 1 evento aberto, pula o menu.
///
/// Sem nenhum evento aberto, pergunta se quer criar um evento (em vez de
/// criar um mês em silêncio) — "Sim" leva pra tela de criação de evento,
/// "Não" só avisa que não dá pra lançar despesa sem evento aberto.
Future<void> openNewExpenseFlow(
  BuildContext context,
  WidgetRef ref, {
  bool useSelectedEvent = false,
}) async {
  final current = await ref.read(selectedEventProvider.future);
  if (!context.mounted) {
    return;
  }
  if (useSelectedEvent && current != null && current.isOpen) {
    await _openFormForEvent(context, ref, current);
    return;
  }
  final groups = await ref.read(groupsProvider.future);
  if (groups.isEmpty) {
    if (context.mounted) {
      await showCreateGroupFirstDialog(context, ref);
    }
    return;
  }
  final groupIds = groups.map((group) => group.id).toSet();
  final openEvents = (await ref.read(eventsRepositoryProvider).list())
      .where((item) => item.isOpen && groupIds.contains(item.groupId))
      .toList();
  if (!context.mounted) {
    return;
  }

  EventModel? event;
  if (openEvents.isNotEmpty) {
    if (groups.length == 1 && openEvents.length == 1) {
      event = openEvents.first;
    } else {
      final choice =
          await _pickExpenseDestination(context, groups, openEvents, current);
      if (!context.mounted || choice == null) {
        return;
      }
      if (choice.createEvent) {
        ref.read(pendingAutoOpenEventProvider.notifier).state = true;
        context.go('/events');
        return;
      }
      event = choice.event;
    }
  }
  // O evento escolhido vira a seleção das outras telas (Despesas,
  // Relatório...), pra depois de salvar a pessoa achar a despesa nele.
  if (event != null) {
    selectEvent(ref, groupId: event.groupId, eventId: event.id);
  }

  if (event == null) {
    final wantsToCreate = await _confirmCreateEvent(context);
    if (!context.mounted || wantsToCreate == null) {
      return;
    }
    if (wantsToCreate) {
      ref.read(pendingAutoOpenEventProvider.notifier).state = true;
      context.go('/events');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Não é possível adicionar despesa: não há evento aberto.')),
      );
    }
    return;
  }

  await _openFormForEvent(context, ref, event);
}

Future<void> _openFormForEvent(
    BuildContext context, WidgetRef ref, EventModel event) async {
  final users = await _loadEventUsers(ref, event.groupId, eventId: event.id);
  final categories = await _loadCategoryNames(ref);
  if (context.mounted) {
    await _openExpenseForm(context, ref, event, users, categories);
  }
}

/// Menu "onde lançar": grupo + evento aberto daquele grupo. null = fechou
/// sem escolher; `createEvent` = o grupo escolhido não tem evento aberto e
/// a pessoa pediu pra criar um.
Future<({EventModel? event, bool createEvent})?> _pickExpenseDestination(
  BuildContext context,
  List<GroupModel> groups,
  List<EventModel> openEvents,
  EventModel? current,
) {
  var groupId = groups.any((group) => group.id == current?.groupId)
      ? current!.groupId
      : groups.first.id;
  List<EventModel> eventsOf(String id) =>
      openEvents.where((item) => item.groupId == id).toList();
  String? defaultEventFor(String id) {
    final events = eventsOf(id);
    if (events.isEmpty) {
      return null;
    }
    return events.any((item) => item.id == current?.id)
        ? current!.id
        : events.first.id;
  }

  var eventId = defaultEventFor(groupId);

  return showModalBottomSheet<({EventModel? event, bool createEvent})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) {
        final groupEvents = eventsOf(groupId);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nova despesa',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                GlassDropdownField<String>(
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
                        eventId = defaultEventFor(value);
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (groupEvents.isEmpty) ...[
                  Text(
                    'Nenhum evento aberto neste grupo.',
                    style: TextStyle(
                        color: Theme.of(sheetContext).colorScheme.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(sheetContext)
                        .pop((event: null, createEvent: true)),
                    icon: const Icon(Icons.add),
                    label: const Text('Criar evento'),
                  ),
                ] else
                  GlassDropdownField<String>(
                    key: ValueKey('picker-event-$groupId'),
                    initialValue: eventId,
                    decoration: const InputDecoration(labelText: 'Evento'),
                    items: groupEvents
                        .map((item) => DropdownMenuItem(
                            value: item.id, child: Text(item.name)))
                        .toList(),
                    onChanged: (value) => setState(() => eventId = value),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: eventId == null
                      ? null
                      : () => Navigator.of(sheetContext).pop((
                            event: groupEvents
                                .firstWhere((item) => item.id == eventId),
                            createEvent: false,
                          )),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// null = popup fechado sem escolher (toque fora); true/false = resposta.
Future<bool?> _confirmCreateEvent(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nenhum evento aberto'),
      content: const Text(
          'Você não tem nenhum evento aberto no momento. Deseja criar um evento agora?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sim, criar evento')),
      ],
    ),
  );
}

/// Abre o formulário de despesa em tela cheia (Etapa 8 do roteiro de UX):
/// valor em destaque primeiro, "quem pagou" e "parcelas" como seções
/// avançadas que só aparecem quando o usuário pede. Nenhum campo enviado
/// ao backend mudou — é só reorganização de apresentação.
Future<void> _openExpenseForm(
  BuildContext context,
  WidgetRef ref,
  EventModel event,
  List<UserOptionModel> users,
  List<String> categories, {
  ExpenseModel? expense,
}) async {
  if (users.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Cadastre ao menos um usuário antes de criar despesas.')),
    );
    return;
  }

  final descriptionController =
      TextEditingController(text: expense?.description ?? '');
  final amountController = TextEditingController(
    text: expense == null
        ? ''
        : formatCurrencyBRL(expense.amount).replaceFirst('R\$ ', ''),
  );
  var selectedExpenseDate = expense?.expenseDate ?? DateTime.now();
  final categoryOptions = [...categories];
  var selectedCategory = categoryOptions.contains(expense?.category)
      ? expense!.category
      : categoryOptions.first;
  // Grupo/evento já chegam escolhidos (menu de "Nova despesa", ou o evento
  // da despesa sendo editada) — o form só mostra onde vai lançar.
  final groups = await ref.read(groupsProvider.future);
  final groupName = _groupName(groups, event.groupId);
  // Só admin cria temporário (regra do backend): só ele vê o botão.
  final isGroupAdmin = await ref
          .read(groupRoleProvider(event.groupId).future)
          .catchError((_) => null) ==
      'ADMIN';
  var currentUsers = users;

  late Set<String> selectedParticipants;
  late Map<String, TextEditingController> shareCountControllers;
  late Map<String, TextEditingController> shareDescriptionControllers;
  late Map<String, TextEditingController> shareAmountControllers;
  late Set<String> selectedPayerIds;
  late Map<String, TextEditingController> payerControllers;
  late String singlePayerId;
  final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
  // Divisão por valor: quem teve o valor digitado pelo usuário. Os demais
  // são recalculados com o que falta do total, dividido igualmente.
  final editedShareAmountIds = <String>{};

  // (Re)monta todo o estado que depende de quem pode participar/pagar —
  // chamado na montagem inicial e de novo sempre que o grupo muda, já que
  // trocar de grupo troca o conjunto de integrantes disponíveis.
  void initUserDependentState(List<UserOptionModel> usersForForm) {
    selectedParticipants = expense == null
        ? usersForForm.map((user) => user.id).toSet()
        : expense.participants.map((participant) => participant.userId).toSet();
    shareCountControllers = {
      for (final user in usersForForm)
        user.id: TextEditingController(
          text: _initialShareCount(user.id, expense),
        ),
    };
    shareDescriptionControllers = {
      for (final user in usersForForm)
        user.id: TextEditingController(
          text: _initialShareDescription(user.id, expense),
        ),
    };
    shareAmountControllers = {
      for (final user in usersForForm)
        user.id: TextEditingController(
          text: _initialShareAmount(user.id, expense),
        ),
    };
    // Ao editar uma despesa já dividida por valor, os valores salvos contam
    // como digitados: mexer num não reescreve os outros ("Dividir
    // igualmente" volta pro automático).
    editedShareAmountIds
      ..clear()
      ..addAll(expense != null && expense.customSplit
          ? expense.participants.map((participant) => participant.userId)
          : const <String>[]);
    final defaultPayerId = usersForForm.any((user) => user.id == currentUserId)
        ? currentUserId!
        : usersForForm.first.id;
    singlePayerId = expense == null || expense.payers.isEmpty
        ? defaultPayerId
        : expense.payers.first.userId;
    payerControllers = {
      for (final user in usersForForm)
        user.id: TextEditingController(
          text: _initialPayerAmount(user.id, expense),
        ),
    };
    // Ao editar, só entra pré-selecionado quem de fato pagou algo (> 0) —
    // não faz sentido mostrar um campo de valor para cada integrante do
    // grupo só porque ele existe, como acontecia antes.
    selectedPayerIds = <String>{
      if (expense != null)
        ...expense.payers
            .where((payer) => payer.amount > 0)
            .map((payer) => payer.userId),
    };
  }

  initUserDependentState(currentUsers);

  var splitPaymentByUser = (expense?.payers.length ?? 0) > 1;
  // "Quem vai dividir": igualmente (por cotas) ou por valor digitado.
  var splitByValue = expense?.customSplit ?? false;
  final installmentsController = TextEditingController(text: '1');
  var installments = 1;
  var showInstallments = false;
  var isSubscription = false;
  // "Avisar participantes" (só em despesa nova): já vem marcado.
  var notifyParticipants = true;
  var isSaving = false;

  void disposeControllers() {
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    _disposeControllers(shareCountControllers.values);
    _disposeControllers(shareDescriptionControllers.values);
    _disposeControllers(shareAmountControllers.values);
  }

  if (!context.mounted) {
    disposeControllers();
    return;
  }

  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (routeContext) => StatefulBuilder(
        builder: (routeContext, setState) {
          final totalShares =
              _totalShareCount(selectedParticipants, shareCountControllers);
          final dialogAmount = parseAmountFieldText(amountController.text);
          final shareValue = dialogAmount == null || totalShares == 0
              ? null
              : dialogAmount / totalShares;
          final sharedByValue =
              _sumShareAmounts(selectedParticipants, shareAmountControllers);

          // Recalcula só quem ainda não teve o valor digitado: o que falta
          // do total (descontado o que já foi digitado) é dividido igual
          // entre eles (centavos que sobram vão pros primeiros).
          void redistributeShareAmounts() {
            final total = parseAmountFieldText(amountController.text);
            if (total == null) {
              return;
            }
            final ids = currentUsers
                .where((user) => selectedParticipants.contains(user.id))
                .map((user) => user.id)
                .toList();
            final free =
                ids.where((id) => !editedShareAmountIds.contains(id)).toList();
            if (free.isEmpty) {
              return;
            }
            final typed = ids
                .where(editedShareAmountIds.contains)
                .map((id) =>
                    parseAmountFieldText(shareAmountControllers[id]!.text) ?? 0)
                .fold<double>(0.0, (sum, value) => sum + value);
            final remaining = total - typed;
            final parts =
                _splitAmountEqually(remaining > 0 ? remaining : 0, free.length);
            for (var index = 0; index < free.length; index++) {
              shareAmountControllers[free[index]]!.text = parts[index];
            }
          }

          // Volta todo mundo pra divisão igual, pra só ajustar quem paga
          // diferente.
          void fillShareAmountsEqually() {
            editedShareAmountIds.clear();
            redistributeShareAmounts();
          }

          // Valida e salva sem fechar a tela: só sai (pop) em caso de
          // sucesso, pra não perder tudo que foi digitado quando algo dá
          // errado (validação local ou erro do backend).
          Future<void> handleSave() async {
            final targetEvent = event;
            final amount = parseAmountFieldText(amountController.text);
            if (amount == null) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(content: Text('Informe o valor da despesa.')),
              );
              return;
            }

            if (descriptionController.text.trim().isEmpty) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(
                    content: Text('Informe uma descrição para a despesa.')),
              );
              return;
            }

            if (selectedParticipants.isEmpty) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(
                    content: Text('Selecione ao menos um participante.')),
              );
              return;
            }

            // Por valor não tem cota extra: cada um entra com 1 cota e o
            // valor que foi digitado.
            final participantShareCounts = splitByValue
                ? {for (final id in selectedParticipants) id: 1}
                : _readParticipantShareCounts(
                    selectedParticipants, shareCountControllers);
            final participantShareDescriptions = splitByValue
                ? <String, String>{}
                : _readParticipantShareDescriptions(
                    selectedParticipants,
                    shareDescriptionControllers,
                  );
            Map<String, double>? participantShareAmounts;
            if (splitByValue) {
              participantShareAmounts = _readParticipantShareAmounts(
                  selectedParticipants, shareAmountControllers);
              if (participantShareAmounts.values.any((value) => value <= 0)) {
                ScaffoldMessenger.of(routeContext).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Informe o valor de cada pessoa que vai dividir.')),
                );
                return;
              }
              final totalShared = participantShareAmounts.values
                  .fold<double>(0.0, (total, value) => total + value);
              if ((totalShared - amount).abs() > 0.009) {
                ScaffoldMessenger.of(routeContext).showSnackBar(
                  SnackBar(
                    content: Text(
                        'A soma dos valores (${formatCurrencyBRL(totalShared)}) precisa bater com o valor total (${formatCurrencyBRL(amount)}).'),
                  ),
                );
                return;
              }
            }
            if (participantShareCounts.length != selectedParticipants.length) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Defina as cotas dos participantes selecionados.')),
              );
              return;
            }

            final payerAmounts = splitPaymentByUser
                ? _readPayerAmounts(payerControllers)
                : {singlePayerId: amount};
            if (payerAmounts.isEmpty) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(content: Text('Informe quem pagou a despesa.')),
              );
              return;
            }

            final totalPaid = payerAmounts.values
                .fold<double>(0.0, (total, value) => total + value);
            if ((totalPaid - amount).abs() > 0.009) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                SnackBar(
                  content: Text(
                      'A soma dos pagadores (${formatCurrencyBRL(totalPaid)}) precisa bater com o valor total (${formatCurrencyBRL(amount)}).'),
                ),
              );
              return;
            }

            final installmentsToSave =
                int.tryParse(installmentsController.text.trim());
            if (installmentsToSave == null || installmentsToSave < 1) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(
                    content: Text('Informe um número de meses válido.')),
              );
              return;
            }

            if (installmentsToSave > 1 && splitPaymentByUser) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(
                    content:
                        Text('Despesa repetida permite apenas um pagador.')),
              );
              return;
            }

            if (isSubscription && splitPaymentByUser) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(
                    content: Text('Assinatura permite apenas um pagador.')),
              );
              return;
            }

            setState(() => isSaving = true);
            try {
              if (expense == null) {
                await ref.read(expensesRepositoryProvider).create(
                      description: descriptionController.text.trim(),
                      amount: amount,
                      expenseDate: selectedExpenseDate,
                      category: selectedCategory,
                      monthId: targetEvent.monthId,
                      eventId: targetEvent.id,
                      participantIds: selectedParticipants.toList(),
                      participantShareCounts: participantShareCounts,
                      participantShareDescriptions:
                          participantShareDescriptions,
                      participantShareAmounts: participantShareAmounts,
                      payerAmounts: payerAmounts,
                      installments: installmentsToSave,
                      subscription: isSubscription,
                      notifyParticipants: notifyParticipants,
                    );
              } else {
                await ref.read(expensesRepositoryProvider).update(
                      id: expense.id,
                      description: descriptionController.text.trim(),
                      amount: amount,
                      expenseDate: selectedExpenseDate,
                      category: selectedCategory,
                      monthId: targetEvent.monthId,
                      eventId: targetEvent.id,
                      participantIds: selectedParticipants.toList(),
                      participantShareCounts: participantShareCounts,
                      participantShareDescriptions:
                          participantShareDescriptions,
                      participantShareAmounts: participantShareAmounts,
                      payerAmounts: payerAmounts,
                    );
              }
              ref.invalidate(currentMonthExpensesProvider);
              ref.invalidate(selectedEventExpensesProvider);
              ref.invalidate(currentMonthReportProvider);
              ref.invalidate(selectedEventReportProvider);
              ref.invalidate(dashboardGroupBalancesProvider);
              if (routeContext.mounted) {
                Navigator.of(routeContext).pop(true);
              }
            } catch (error) {
              if (routeContext.mounted) {
                ScaffoldMessenger.of(routeContext).showSnackBar(
                  SnackBar(
                      content: Text(friendlyApiError(error,
                          fallback: 'Não foi possível salvar a despesa.'))),
                );
                setState(() => isSaving = false);
              }
            }
          }

          return Scaffold(
            appBar: AppBar(
              // Voltar numa pílula, como no resto do app.
              leading: const GlassBackButton(),
              leadingWidth: 56,
              title: Text(expense == null ? 'Nova despesa' : 'Editar despesa'),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                // Sem soma manual do viewInsets.bottom aqui: ao contrário de
                // um bottom sheet (que não redimensiona sozinho), este
                // Scaffold já tem resizeToAvoidBottomInset ligado por
                // padrão e encolhe o body quando o teclado abre. Somar de
                // novo a altura do teclado contava ela duas vezes, inflando
                // o conteúdo rolável bem além do necessário (scroll
                // "infinito" até os botões fixos no bottomNavigationBar).
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$groupName | ${event.name}',
                      style: Theme.of(routeContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AmountField(
                      controller: amountController,
                      autofocus: expense == null,
                      onChanged: (_) => setState(() {
                        if (splitByValue) {
                          redistributeShareAmounts();
                        }
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: descriptionController,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: routeContext,
                          initialDate: selectedExpenseDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          setState(() => selectedExpenseDate = selected);
                        }
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(_formatDate(selectedExpenseDate)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GlassDropdownField<String>(
                      initialValue: selectedCategory,
                      decoration:
                          const InputDecoration(labelText: 'Tipo de despesa'),
                      items: categoryOptions
                          .map((category) => DropdownMenuItem(
                              value: category, child: Text(category)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedCategory = value);
                        }
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final created = await _showCreateCategoryDialog(
                              routeContext, ref);
                          if (created != null) {
                            setState(() {
                              categoryOptions.add(created);
                              categoryOptions.sort();
                              selectedCategory = created;
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Novo tipo'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    Text('Quem pagou',
                        style: Theme.of(routeContext).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    if (!splitPaymentByUser) ...[
                      GlassDropdownField<String>(
                        initialValue: singlePayerId,
                        // Sem label: o título "Quem pagou" logo acima já diz o que é.
                        decoration: const InputDecoration(),
                        items: currentUsers
                            .map((user) => DropdownMenuItem(
                                value: user.id, child: Text(user.nickname)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => singlePayerId = value);
                          }
                        },
                      ),
                      if (installments <= 1) ...[
                        const SizedBox(height: AppSpacing.xs),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => splitPaymentByUser = true),
                          icon: const Icon(Icons.call_split),
                          label: const Text(
                              'Dividir pagamento entre várias pessoas'),
                        ),
                      ],
                    ] else ...[
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: currentUsers.map((user) {
                          final selected = selectedPayerIds.contains(user.id);
                          return FilterChip(
                            selected: selected,
                            label: Text(user.nickname),
                            onSelected: (checked) {
                              setState(() {
                                if (checked) {
                                  selectedPayerIds.add(user.id);
                                } else {
                                  selectedPayerIds.remove(user.id);
                                  payerControllers[user.id]!.text = '0,00';
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (selectedPayerIds.isEmpty)
                        const Text('Selecione quem pagou.')
                      else ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: dialogAmount == null
                                ? null
                                : () => setState(() {
                                      final shares = _splitAmountEqually(
                                          dialogAmount,
                                          selectedPayerIds.length);
                                      var shareIndex = 0;
                                      for (final user in currentUsers) {
                                        if (!selectedPayerIds
                                            .contains(user.id)) {
                                          continue;
                                        }
                                        payerControllers[user.id]!.text =
                                            shares[shareIndex];
                                        shareIndex++;
                                      }
                                    }),
                            icon: const Icon(Icons.balance),
                            label: const Text('Dividir igualmente'),
                          ),
                        ),
                        ...currentUsers
                            .where((user) => selectedPayerIds.contains(user.id))
                            .map(
                              (user) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: AmountField(
                                  controller: payerControllers[user.id]!,
                                  label: 'Valor pago por ${user.nickname}',
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => splitPaymentByUser = false),
                        icon: const Icon(Icons.person),
                        label: const Text('Voltar para um pagador só'),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    Text('Quem vai dividir',
                        style: Theme.of(routeContext).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.balance),
                          label: Text('Igualmente'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.edit_note),
                          label: Text('Por valor'),
                        ),
                      ],
                      selected: {splitByValue},
                      onSelectionChanged: (selection) => setState(() {
                        splitByValue = selection.first;
                        // Ao entrar no modo "por valor" sem nada digitado,
                        // já começa com a divisão igual pra só ajustar.
                        if (splitByValue &&
                            _sumShareAmounts(selectedParticipants,
                                    shareAmountControllers) ==
                                0) {
                          fillShareAmountsEqually();
                        }
                      }),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.done_all, size: 18),
                          label: const Text('Todos'),
                          onPressed: () {
                            setState(() {
                              selectedParticipants
                                ..clear()
                                ..addAll(currentUsers.map((user) => user.id));
                              for (final user in currentUsers) {
                                final current =
                                    shareCountControllers[user.id]!.text;
                                if ((int.tryParse(current) ?? 0) <= 0) {
                                  shareCountControllers[user.id]!.text = '1';
                                }
                              }
                              if (splitByValue) {
                                redistributeShareAmounts();
                              }
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.clear, size: 18),
                          label: const Text('Limpar'),
                          onPressed: () {
                            setState(() {
                              selectedParticipants.clear();
                              editedShareAmountIds.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: currentUsers.map((user) {
                        final selected = selectedParticipants.contains(user.id);
                        return FilterChip(
                          selected: selected,
                          label: Text(user.nickname),
                          onSelected: (checked) {
                            setState(() {
                              if (checked) {
                                selectedParticipants.add(user.id);
                                final current =
                                    shareCountControllers[user.id]!.text;
                                if ((int.tryParse(current) ?? 0) <= 0) {
                                  shareCountControllers[user.id]!.text = '1';
                                }
                              } else {
                                selectedParticipants.remove(user.id);
                                editedShareAmountIds.remove(user.id);
                              }
                              if (splitByValue) {
                                redistributeShareAmounts();
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    // Pessoa sem cadastro na hora: entra no grupo como
                    // temporária e já volta marcada nesta despesa.
                    if (isGroupAdmin) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final added = await _addTemporaryParticipant(
                                routeContext, ref, event.groupId);
                            if (added == null || !routeContext.mounted) {
                              return;
                            }
                            setState(() {
                              currentUsers = [...currentUsers, added];
                              shareCountControllers[added.id] =
                                  TextEditingController(text: '1');
                              shareDescriptionControllers[added.id] =
                                  TextEditingController();
                              shareAmountControllers[added.id] =
                                  TextEditingController();
                              payerControllers[added.id] =
                                  TextEditingController();
                              selectedParticipants.add(added.id);
                              if (splitByValue) {
                                redistributeShareAmounts();
                              }
                            });
                          },
                          icon: const Icon(Icons.person_add_alt_outlined),
                          label:
                              const Text('Adicionar participante temporário'),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(routeContext)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: splitByValue
                            ? [
                                Text(
                                    '${selectedParticipants.length} participantes'),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Soma: '),
                                    MoneyText(sharedByValue,
                                        style: Theme.of(routeContext)
                                            .textTheme
                                            .bodyMedium),
                                    if (dialogAmount != null) ...[
                                      const Text(' de '),
                                      MoneyText(dialogAmount,
                                          style: Theme.of(routeContext)
                                              .textTheme
                                              .bodyMedium),
                                    ],
                                  ],
                                ),
                                if (dialogAmount != null &&
                                    (dialogAmount - sharedByValue).abs() >
                                        0.009)
                                  Text(
                                    dialogAmount > sharedByValue
                                        ? 'Faltam ${formatCurrencyBRL(dialogAmount - sharedByValue)}'
                                        : 'Passou ${formatCurrencyBRL(sharedByValue - dialogAmount)}',
                                    style: TextStyle(
                                        color: Theme.of(routeContext)
                                            .colorScheme
                                            .error),
                                  ),
                              ]
                            : [
                                Text(
                                    '${selectedParticipants.length} participantes'),
                                if (totalShares > selectedParticipants.length)
                                  Text('$totalShares cotas'),
                                if (shareValue == null)
                                  const Text('Divisão: -')
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(totalShares >
                                              selectedParticipants.length
                                          ? 'Valor por cota: '
                                          : 'Cada participante: '),
                                      MoneyText(shareValue,
                                          style: Theme.of(routeContext)
                                              .textTheme
                                              .bodyMedium),
                                    ],
                                  ),
                              ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Sem o link "Dividir igualmente" aqui: o botão
                    // "Igualmente" acima já faz isso (pedido do usuário).
                    if (selectedParticipants.isEmpty)
                      const Text('Selecione ao menos um participante.')
                    else
                      ...currentUsers
                          .where(
                              (user) => selectedParticipants.contains(user.id))
                          .map(
                        (user) {
                          if (splitByValue) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AmountField(
                                controller: shareAmountControllers[user.id]!,
                                label: user.nickname,
                                onChanged: (_) => setState(() {
                                  editedShareAmountIds.add(user.id);
                                  redistributeShareAmounts();
                                }),
                              ),
                            );
                          }
                          final count = _shareCountFor(
                            user.id,
                            shareCountControllers,
                          );
                          final hasExtraShare = _hasExtraShare(
                            user.id,
                            shareCountControllers,
                            shareDescriptionControllers,
                          );
                          final userAmount =
                              shareValue == null ? null : shareValue * count;
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.nickname,
                                            style: Theme.of(routeContext)
                                                .textTheme
                                                .bodyLarge,
                                          ),
                                          if (userAmount != null)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('Participação: ',
                                                    style:
                                                        Theme.of(routeContext)
                                                            .textTheme
                                                            .bodySmall),
                                                MoneyText(userAmount,
                                                    style:
                                                        Theme.of(routeContext)
                                                            .textTheme
                                                            .bodySmall),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (!hasExtraShare)
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            shareCountControllers[user.id]!
                                                .text = '2';
                                          });
                                        },
                                        icon: const Icon(Icons.group_add),
                                        label: const Text('Cota extra'),
                                      ),
                                  ],
                                ),
                                if (hasExtraShare) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Diminuir cota',
                                        onPressed: count <= 2
                                            ? null
                                            : () {
                                                setState(() {
                                                  shareCountControllers[
                                                          user.id]!
                                                      .text = '${count - 1}';
                                                });
                                              },
                                        icon: const Icon(Icons.remove),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: KeyboardDoneBar(
                                            child: TextField(
                                          controller:
                                              shareCountControllers[user.id],
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            labelText: 'Cotas',
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        )),
                                      ),
                                      IconButton(
                                        tooltip: 'Aumentar cota',
                                        onPressed: () {
                                          setState(() {
                                            shareCountControllers[user.id]!
                                                .text = '${count + 1}';
                                          });
                                        },
                                        icon: const Icon(Icons.add),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Remover cota extra',
                                        onPressed: () {
                                          setState(() {
                                            shareCountControllers[user.id]!
                                                .text = '1';
                                            shareDescriptionControllers[
                                                    user.id]!
                                                .clear();
                                          });
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  TextField(
                                    controller:
                                        shareDescriptionControllers[user.id],
                                    maxLength: 160,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      labelText: 'Descrição',
                                      hintText: 'Ex.: Rafa e Gertrudes',
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    if (expense == null && event.monthId != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      if (!showInstallments && !isSubscription) ...[
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => showInstallments = true),
                          icon: const Icon(Icons.event_repeat),
                          label: const Text('Repetir despesa'),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            isSubscription = true;
                            splitPaymentByUser = false;
                          }),
                          icon: const Icon(Icons.autorenew),
                          label: const Text('Assinatura (repete todo mês)'),
                        ),
                      ] else if (showInstallments) ...[
                        // Digitável e também com +/- pra ajustar sem
                        // abrir o teclado.
                        Row(
                          children: [
                            IconButton.outlined(
                              tooltip: 'Diminuir meses',
                              onPressed: installments <= 1
                                  ? null
                                  : () => setState(() {
                                        installments -= 1;
                                        installmentsController.text =
                                            '$installments';
                                      }),
                              icon: const Icon(Icons.remove),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: KeyboardDoneBar(
                                  child: TextField(
                                controller: installmentsController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                    labelText: 'Quantos meses'),
                                onChanged: (value) {
                                  final parsed = int.tryParse(value) ?? 1;
                                  setState(() {
                                    installments = parsed;
                                    if (installments > 1) {
                                      splitPaymentByUser = false;
                                    }
                                  });
                                },
                              )),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton.outlined(
                              tooltip: 'Aumentar meses',
                              onPressed: () => setState(() {
                                installments += 1;
                                installmentsController.text = '$installments';
                                splitPaymentByUser = false;
                              }),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'O valor inteiro entra de novo em cada mês seguinte, com a mesma divisão (não é dividido entre os meses).',
                          style: Theme.of(routeContext).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            showInstallments = false;
                            installments = 1;
                            installmentsController.text = '1';
                          }),
                          icon: const Icon(Icons.close),
                          label: const Text('Não repetir'),
                        ),
                      ] else if (isSubscription) ...[
                        Text(
                          'Essa despesa vai repetir todo mês automaticamente, com o mesmo valor e divisão, até alguém finalizar a assinatura.',
                          style: Theme.of(routeContext).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => isSubscription = false),
                          icon: const Icon(Icons.close),
                          label: const Text('Não é assinatura'),
                        ),
                      ],
                    ],
                    if (expense != null &&
                        expense.installmentGroupId != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Icon(
                              expense.isSubscription
                                  ? Icons.autorenew
                                  : Icons.event_repeat,
                              size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            expense.installmentLabel ??
                                (expense.isSubscription
                                    ? 'Assinatura'
                                    : 'Despesa repetida'),
                            style: Theme.of(routeContext).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        expense.isSubscription
                            ? 'Essa despesa repete todo mês automaticamente até ser finalizada.'
                            : 'O número de meses não pode ser alterado depois de criada.',
                        style: Theme.of(routeContext).textTheme.bodySmall,
                      ),
                      if (expense.isSubscription &&
                          !expense.subscriptionCancelled) ...[
                        const SizedBox(height: AppSpacing.xs),
                        TextButton.icon(
                          onPressed: () async {
                            final cancelled = await _confirmCancelSubscription(
                                routeContext, ref, expense);
                            if (cancelled && routeContext.mounted) {
                              Navigator.of(routeContext).pop(false);
                            }
                          },
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Finalizar assinatura'),
                        ),
                      ],
                    ],
                    if (expense == null) ...[
                      const SizedBox(height: AppSpacing.md),
                      CheckboxListTile(
                        value: notifyParticipants,
                        onChanged: (value) =>
                            setState(() => notifyParticipants = value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Avisar participantes'),
                        subtitle: const Text(
                            'Envia uma notificação para quem participa desta despesa.'),
                      ),
                    ],
                    if (expense != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final deleted = await _confirmDeleteExpense(
                              routeContext,
                              ref,
                              expense,
                            );
                            if (deleted && routeContext.mounted) {
                              Navigator.of(routeContext).pop(false);
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Excluir despesa'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.of(routeContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: isSaving ? null : () => handleSave(),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  // A validação e o salvamento já rodaram dentro de handleSave, com a tela
  // ainda aberta — só chegamos aqui com saved == true depois de sucesso
  // real, então só falta avisar e liberar os controllers.
  if (saved != true || !context.mounted) {
    disposeControllers();
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(expense == null
          ? 'Despesa cadastrada com sucesso.'
          : 'Despesa atualizada com sucesso.'),
    ),
  );
  disposeControllers();
}

/// Detalhe enxuto de uma despesa já cadastrada — é o que abre ao tocar numa
/// despesa da lista, pra todo mundo. Quem pode editar (Adm ou quem
/// cadastrou, com o evento aberto) vê o botão "Editar", que abre o
/// formulário completo. Retorna true quando a pessoa pediu pra editar.
Future<bool> _openExpenseDetails(
  BuildContext context,
  ExpenseModel expense, {
  required bool canEdit,
}) async {
  final installmentLabel = expense.installmentLabel;
  final wantsEdit = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (routeContext) {
        final theme = Theme.of(routeContext);
        final muted = theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        return Scaffold(
          appBar: AppBar(
            leading: const GlassBackButton(),
            leadingWidth: 56,
            title: const Text('Despesa'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                Text(expense.description, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                MoneyText(expense.amount,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    _formatDate(expense.expenseDate),
                    expense.category,
                    if (installmentLabel != null) installmentLabel,
                  ].join('  ·  '),
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.xl),
                _detailSectionTitle(routeContext, 'Quem pagou'),
                ...sortedByNamePtBr(expense.payers, (payer) => payer.nickname)
                    .map((payer) => _detailPersonRow(routeContext, payer.userId,
                        payer.nickname, payer.amount)),
                const SizedBox(height: AppSpacing.lg),
                _detailSectionTitle(routeContext, 'Quem vai dividir'),
                ...sortedByNamePtBr(expense.participants,
                        (participant) => participant.nickname)
                    .map((participant) => _detailPersonRow(
                          routeContext,
                          participant.userId,
                          participant.shareCount > 1
                              ? '${participant.nickname} (x${participant.shareCount})'
                              : participant.nickname,
                          participant.shareAmount,
                          note: participant.shareDescription,
                        )),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(routeContext).pop(false),
                      child: const Text('Fechar'),
                    ),
                  ),
                  if (canEdit) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(routeContext).pop(true),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  return wantsEdit == true;
}

Widget _detailSectionTitle(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

Widget _detailPersonRow(
  BuildContext context,
  String userId,
  String name,
  double amount, {
  String? note,
}) {
  final theme = Theme.of(context);
  final trimmedNote = note?.trim();
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        PersonAvatar(name: name, seed: userId, radius: 14),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.bodyMedium),
              if (trimmedNote != null && trimmedNote.isNotEmpty)
                Text(trimmedNote,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        MoneyText(amount, style: theme.textTheme.bodyMedium),
      ],
    ),
  );
}

Future<String?> _showCreateCategoryDialog(
    BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final saved = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Novo tipo de despesa'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salvar')),
        ],
      );
    },
  );

  if (saved != true || !context.mounted) {
    controller.dispose();
    return null;
  }

  final name = controller.text.trim();
  controller.dispose();
  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Informe o nome do tipo de despesa.')),
    );
    return null;
  }

  try {
    final category =
        await ref.read(expenseCategoriesRepositoryProvider).create(name);
    ref.invalidate(expenseCategoriesProvider);
    return category.name;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível criar o tipo.'))),
      );
    }
    return null;
  }
}

/// Quem pode participar/pagar: com [eventId], integrantes fixos + pessoas
/// temporárias daquele evento. Quem foi removido do grupo mas está na
/// despesa sendo editada ([keepUserIds]) continua na lista — senão sairia
/// da divisão ao salvar.
/// Pop-up do form de despesa: cria uma pessoa temporária no grupo só com o
/// nome (como "Incluir temporário" em Grupos) e devolve ela pra entrar na
/// lista de participantes. null = cancelou ou falhou.
Future<UserOptionModel?> _addTemporaryParticipant(
    BuildContext context, WidgetRef ref, String groupId) async {
  final nameController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Adicionar participante temporário'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameController,
            maxLength: 40,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
            onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
          ),
          const SizedBox(height: 12),
          Text(
            'Entra no grupo como temporário, sem precisar de conta, e já fica '
            'marcado nesta despesa.',
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Adicionar')),
      ],
    ),
  );
  final nickname = nameController.text.trim();
  nameController.dispose();
  if (confirmed != true || !context.mounted) {
    return null;
  }
  if (nickname.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da pessoa.')));
    return null;
  }
  try {
    final member = await ref
        .read(groupsRepositoryProvider)
        .createPlaceholder(groupId, nickname: nickname, temporary: true);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
    return UserOptionModel(
        id: member.userId, nickname: member.nickname, active: true);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível adicionar a pessoa.'))));
    }
    return null;
  }
}

Future<List<UserOptionModel>> _loadEventUsers(WidgetRef ref, String groupId,
    {String? eventId, Set<String> keepUserIds = const {}}) async {
  final members = await ref
      .read(groupsRepositoryProvider)
      .listMembers(groupId, eventId: eventId);
  return members
      .where((member) => member.active || keepUserIds.contains(member.userId))
      .map((member) => UserOptionModel(
            id: member.userId,
            nickname: member.nickname,
            active: true,
          ))
      .toList();
}

Future<List<String>> _loadCategoryNames(WidgetRef ref) async {
  try {
    final categories = await ref.read(expenseCategoriesProvider.future);
    if (categories.isEmpty) {
      return ['Geral'];
    }
    return categories.map((category) => category.name).toList();
  } catch (_) {
    return ['Geral'];
  }
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _formatDateShort(DateTime value) {
  final year = (value.year % 100).toString().padLeft(2, '0');
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/$year';
}

String? _expenseShareSummary(ExpenseModel expense) {
  final extraShares = expense.participants
      .where((participant) => participant.shareCount > 1)
      .toList();
  if (extraShares.isEmpty) {
    return null;
  }
  final totalShares = expense.participants.fold<int>(
    0,
    (total, participant) => total + participant.shareCount,
  );
  final users = extraShares
      .map(
          (participant) => '${participant.nickname} x${participant.shareCount}')
      .join(', ');
  return '$totalShares cotas | $users';
}

String _initialPayerAmount(String userId, ExpenseModel? expense) {
  if (expense == null) {
    return '0,00';
  }
  final matching = expense.payers.where((payer) => payer.userId == userId);
  if (matching.isEmpty) {
    return '0,00';
  }
  return formatCurrencyBRL(matching.first.amount).replaceFirst('R\$ ', '');
}

String _initialShareCount(String userId, ExpenseModel? expense) {
  if (expense == null) {
    return '1';
  }
  final matching =
      expense.participants.where((participant) => participant.userId == userId);
  if (matching.isEmpty) {
    return '1';
  }
  return matching.first.shareCount.toString();
}

String _initialShareDescription(String userId, ExpenseModel? expense) {
  if (expense == null) {
    return '';
  }
  final matching =
      expense.participants.where((participant) => participant.userId == userId);
  if (matching.isEmpty) {
    return '';
  }
  return matching.first.shareDescription ?? '';
}

/// Valor de cada um na divisão por valor — só preenchido ao editar uma
/// despesa que já foi dividida assim.
String _initialShareAmount(String userId, ExpenseModel? expense) {
  if (expense == null || !expense.customSplit) {
    return '0,00';
  }
  final matching =
      expense.participants.where((participant) => participant.userId == userId);
  if (matching.isEmpty) {
    return '0,00';
  }
  return formatCurrencyBRL(matching.first.shareAmount).replaceFirst('R\$ ', '');
}

Map<String, double> _readParticipantShareAmounts(
  Set<String> selectedParticipants,
  Map<String, TextEditingController> controllers,
) {
  return {
    for (final userId in selectedParticipants)
      userId: parseAmountFieldText(controllers[userId]?.text ?? '') ?? 0,
  };
}

double _sumShareAmounts(
  Set<String> selectedParticipants,
  Map<String, TextEditingController> controllers,
) {
  return _readParticipantShareAmounts(selectedParticipants, controllers)
      .values
      .fold<double>(0.0, (total, value) => total + value);
}

Map<String, double> _readPayerAmounts(
    Map<String, TextEditingController> controllers) {
  final result = <String, double>{};
  for (final entry in controllers.entries) {
    final value = parseAmountFieldText(entry.value.text) ?? 0;
    if (value > 0) {
      result[entry.key] = value;
    }
  }
  return result;
}

/// Divide [total] em [count] partes iguais, em centavos, pro botão
/// "Dividir igualmente" dos pagadores — os centavos que sobram da divisão
/// (ex.: R\$ 100,00 ÷ 3 = R\$ 33,33 com 1 centavo sobrando) vão pros
/// primeiros pagadores da lista, pra soma bater exatamente com o total
/// (mesma regra de arredondamento que a validação de "soma dos pagadores"
/// exige antes de salvar).
List<String> _splitAmountEqually(double total, int count) {
  if (count <= 0) {
    return const [];
  }
  final totalCents = (total * 100).round();
  final baseCents = totalCents ~/ count;
  final remainder = totalCents % count;
  return List.generate(count, (index) {
    final cents = baseCents + (index < remainder ? 1 : 0);
    return formatCurrencyBRL(cents / 100).replaceFirst('R\$ ', '');
  });
}

int _shareCountFor(
  String userId,
  Map<String, TextEditingController> controllers,
) {
  final value = int.tryParse(controllers[userId]?.text.trim() ?? '') ?? 1;
  return value < 1 ? 1 : value;
}

int _totalShareCount(
  Set<String> selectedParticipants,
  Map<String, TextEditingController> controllers,
) {
  return selectedParticipants.fold<int>(
    0,
    (total, userId) => total + _shareCountFor(userId, controllers),
  );
}

bool _hasExtraShare(
  String userId,
  Map<String, TextEditingController> shareCountControllers,
  Map<String, TextEditingController> shareDescriptionControllers,
) {
  return _shareCountFor(userId, shareCountControllers) > 1 ||
      (shareDescriptionControllers[userId]?.text.trim().isNotEmpty ?? false);
}

Map<String, int> _readParticipantShareCounts(
  Set<String> selectedParticipants,
  Map<String, TextEditingController> controllers,
) {
  final result = <String, int>{};
  for (final userId in selectedParticipants) {
    result[userId] = _shareCountFor(userId, controllers);
  }
  return result;
}

Map<String, String> _readParticipantShareDescriptions(
  Set<String> selectedParticipants,
  Map<String, TextEditingController> controllers,
) {
  final result = <String, String>{};
  for (final userId in selectedParticipants) {
    final value = controllers[userId]?.text.trim() ?? '';
    if (value.isNotEmpty) {
      result[userId] = value;
    }
  }
  return result;
}

void _disposeControllers(Iterable<TextEditingController> controllers) {
  for (final controller in controllers) {
    controller.dispose();
  }
}
