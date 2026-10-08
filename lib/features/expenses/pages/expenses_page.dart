import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/api_error.dart';
import '../../../shared/widgets/amount_field.dart';
import '../../../shared/widgets/keyboard_done_bar.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/auto_collapsing_fab.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../auth/services/auth_repository.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../events/models/event_model.dart';
import '../../events/services/events_repository.dart';
import '../../events/services/new_event_intent.dart';
import '../../groups/services/groups_repository.dart';
import '../../reports/services/reports_repository.dart';
import '../../users/models/user_option_model.dart';
import '../models/expense_model.dart';
import '../services/expense_categories_repository.dart';
import '../services/expenses_repository.dart';
import '../services/new_expense_intent.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(selectedEventProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final expensesAsync = ref.watch(selectedEventExpensesProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final showOnlyMine = ref.watch(showOnlyMyExpensesProvider);

    if (ref.read(pendingAutoOpenExpenseProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        if (!ref.read(pendingAutoOpenExpenseProvider)) {
          return;
        }
        ref.read(pendingAutoOpenExpenseProvider.notifier).state = false;
        _openNewExpenseFlow(context, ref);
      });
    }

    return AppScaffold(
      title: 'Despesas',
      floatingActionButton: AutoCollapsingFab(
        label: 'Nova despesa',
        onPressed: () => _openNewExpenseFlow(context, ref),
      ),
      child: eventAsync.when(
        data: (event) {
          if (event == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => _openNewExpenseFlow(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar despesa'),
              ),
            );
          }
          final groupName = _groupName(groupsAsync.valueOrNull, event.groupId);
          final isGroupAdmin =
              ref.watch(groupRoleProvider(event.groupId)).valueOrNull ==
                  'ADMIN';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: eventsAsync.when(
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
                    return DropdownButtonFormField<String>(
                      initialValue: event.id,
                      decoration: const InputDecoration(labelText: 'Evento'),
                      items: items
                          .map((item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                  _eventLabel(item, groupsAsync.valueOrNull))))
                          .toList(),
                      onChanged: (value) {
                        ref.read(selectedEventIdProvider.notifier).state =
                            value;
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  '$groupName | ${event.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              CheckboxListTile(
                value: showOnlyMine,
                onChanged: (value) => ref
                    .read(showOnlyMyExpensesProvider.notifier)
                    .state = value ?? false,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                title: const Text('Mostrar só minhas despesas'),
              ),
              Expanded(
                child: expensesAsync.when(
                  data: (expenses) {
                    final visibleExpenses = showOnlyMine
                        ? expenses
                            .where((expense) =>
                                _isUserInvolved(expense, currentUser?.id))
                            .toList()
                        : expenses;
                    if (visibleExpenses.isEmpty) {
                      return EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: showOnlyMine
                            ? 'Você não participa de nenhuma despesa deste evento.'
                            : 'Nenhuma despesa cadastrada.',
                        message: showOnlyMine
                            ? 'Desmarque o filtro para ver as despesas de todo o grupo.'
                            : 'Toque em "+" para registrar o primeiro gasto deste evento.',
                      );
                    }
                    final sortedExpenses = [...visibleExpenses]
                      ..sort((first, second) {
                        final dateComparison =
                            second.expenseDate.compareTo(first.expenseDate);
                        if (dateComparison != 0) {
                          return dateComparison;
                        }
                        return second.createdAt.compareTo(first.createdAt);
                      });
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: sortedExpenses.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final expense = sortedExpenses[index];
                        final canChange = _canChangeExpense(
                          expense,
                          currentUser?.id,
                          isGroupAdmin,
                        );
                        final shareSummary = _expenseShareSummary(expense);
                        final installmentLabel = expense.installmentLabel;
                        return ListTile(
                          leading: SizedBox(
                            width: 64,
                            child: Text(
                              _formatDateShort(expense.expenseDate),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          onTap: () async {
                            if (!canChange) {
                              await _openExpenseDetails(context, expense);
                              return;
                            }
                            if (!event.isOpen) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Este evento nao esta aberto para edicao de despesas.')),
                              );
                              return;
                            }
                            final users =
                                await _loadEventUsers(ref, event.groupId);
                            final categories = await _loadCategoryNames(ref);
                            if (context.mounted) {
                              await _openExpenseForm(
                                  context, ref, event, users, categories,
                                  expense: expense);
                            }
                          },
                          title: Text(expense.description),
                          subtitle: [shareSummary, installmentLabel]
                                  .whereType<String>()
                                  .isEmpty
                              ? null
                              : Text([shareSummary, installmentLabel]
                                  .whereType<String>()
                                  .join(' | ')),
                          trailing: MoneyText(expense.amount),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingState(),
                  error: (error, _) => ErrorState(
                    message: friendlyApiError(error,
                        fallback: 'Não foi possível carregar as despesas.'),
                    onRetry: () =>
                        ref.invalidate(selectedEventExpensesProvider),
                  ),
                ),
              ),
            ],
          );
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

String _eventLabel(EventModel event, List<dynamic>? groups) {
  return '${event.name} | ${_groupName(groups, event.groupId)}';
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

/// Fluxo único de "adicionar despesa": resolve o evento atual e abre o
/// formulário — usado pelo FAB desta tela, pelo botão de estado vazio e
/// pelo CTA "Nova despesa" da Home (via [pendingAutoOpenExpenseProvider]).
///
/// Usa o grupo/evento já selecionado (o mesmo que aparece na tela de
/// Despesas) em vez de perguntar de novo em qual grupo lançar — perguntar
/// de novo era redundante e confuso quando a pessoa já estava vendo o
/// evento certo na tela e só queria tocar em "+".
///
/// Sem evento aberto no grupo, pergunta se quer criar um evento (em vez de
/// criar um mês em silêncio) — "Sim" leva pra tela de criação de evento,
/// "Não" só avisa que não dá pra lançar despesa sem evento aberto.
Future<void> _openNewExpenseFlow(BuildContext context, WidgetRef ref) async {
  final event = await ref.read(selectedEventProvider.future);
  if (!context.mounted) {
    return;
  }

  if (event == null || !event.isOpen) {
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
                'Não é possível adicionar despesa: não há evento aberto neste grupo.')),
      );
    }
    return;
  }

  final users = await _loadEventUsers(ref, event.groupId);
  final categories = await _loadCategoryNames(ref);
  if (context.mounted) {
    await _openExpenseForm(context, ref, event, users, categories);
  }
}

/// null = popup fechado sem escolher (toque fora); true/false = resposta.
Future<bool?> _confirmCreateEvent(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nenhum evento aberto'),
      content: const Text(
          'Este grupo não tem nenhum evento aberto no momento. Deseja criar um evento agora?'),
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
              Text('Cadastre ao menos um usuario antes de criar despesas.')),
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
  // Grupo/evento de destino da despesa: pré-selecionados com o que já
  // estava na tela (evento sendo navegado), mas só ficam editáveis ao
  // criar uma despesa nova — dá pra confirmar ou corrigir antes de salvar,
  // em vez de confiar só no contexto de navegação (que pode ser ambíguo
  // vindo da Home, por exemplo). `groupsProvider` já costuma estar em
  // cache (a própria tela de Despesas o observa), então ler de novo aqui
  // não dispara outra chamada de rede na maioria das vezes.
  final groups = await ref.read(groupsProvider.future);
  var selectedGroupId = event.groupId;
  EventModel? currentEvent = event;
  var currentUsers = users;
  var openEventsForGroup =
      (await ref.read(eventsRepositoryProvider).list(groupId: event.groupId))
          .where((item) => item.status == 'OPEN')
          .toList();
  if (openEventsForGroup.every((item) => item.id != event.id)) {
    openEventsForGroup = [...openEventsForGroup, event];
  }

  late Set<String> selectedParticipants;
  late Map<String, TextEditingController> shareCountControllers;
  late Map<String, TextEditingController> shareDescriptionControllers;
  late Set<String> selectedPayerIds;
  late Map<String, TextEditingController> payerControllers;
  late String singlePayerId;
  final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;

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
  final installmentsController = TextEditingController(text: '1');
  var installments = 1;
  var showInstallments = false;
  var isSubscription = false;
  var isSaving = false;

  void disposeControllers() {
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    _disposeControllers(shareCountControllers.values);
    _disposeControllers(shareDescriptionControllers.values);
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

          // Troca o grupo de destino (só no modo "nova despesa"): busca os
          // eventos abertos e os integrantes do novo grupo, e reconstrói
          // todo o estado de participantes/pagadores pro novo conjunto de
          // pessoas — o que estava marcado pro grupo anterior não faz
          // sentido mais.
          Future<void> handleGroupChange(String newGroupId) async {
            if (newGroupId == selectedGroupId) {
              return;
            }
            final newEvents = await ref
                .read(eventsRepositoryProvider)
                .list(groupId: newGroupId);
            final newOpenEvents =
                newEvents.where((item) => item.status == 'OPEN').toList();
            final newUsers = await _loadEventUsers(ref, newGroupId);
            // Descarta os controllers do grupo anterior antes de criar os
            // novos pro conjunto de pessoas do novo grupo — sem isso, cada
            // troca de grupo deixava os TextEditingControllers antigos sem
            // dispose, vazando recursos.
            _disposeControllers(payerControllers.values);
            _disposeControllers(shareCountControllers.values);
            _disposeControllers(shareDescriptionControllers.values);
            setState(() {
              selectedGroupId = newGroupId;
              openEventsForGroup = newOpenEvents;
              currentEvent = newOpenEvents.isEmpty ? null : newOpenEvents.first;
              currentUsers = newUsers;
              initUserDependentState(currentUsers);
            });
          }

          void handleEventChange(String newEventId) {
            final found =
                openEventsForGroup.where((item) => item.id == newEventId);
            if (found.isEmpty) {
              return;
            }
            setState(() => currentEvent = found.first);
          }

          // Valida e salva sem fechar a tela: só sai (pop) em caso de
          // sucesso, pra não perder tudo que foi digitado quando algo dá
          // errado (validação local ou erro do backend).
          Future<void> handleSave() async {
            final targetEvent = currentEvent;
            if (targetEvent == null) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(
                    content:
                        Text('Selecione um evento aberto para continuar.')),
              );
              return;
            }
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

            final participantShareCounts = _readParticipantShareCounts(
                selectedParticipants, shareCountControllers);
            final participantShareDescriptions =
                _readParticipantShareDescriptions(
              selectedParticipants,
              shareDescriptionControllers,
            );
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
                    content: Text('Informe um número de parcelas válido.')),
              );
              return;
            }

            if (installmentsToSave > 1 && splitPaymentByUser) {
              ScaffoldMessenger.of(routeContext).showSnackBar(
                const SnackBar(
                    content:
                        Text('Despesa parcelada permite apenas um pagador.')),
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
                      payerAmounts: payerAmounts,
                      installments: installmentsToSave,
                      subscription: isSubscription,
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
                    if (expense == null) ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedGroupId,
                        decoration: const InputDecoration(labelText: 'Grupo'),
                        items: groups
                            .map((group) => DropdownMenuItem(
                                value: group.id, child: Text(group.name)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            handleGroupChange(value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (openEventsForGroup.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: Text(
                            'Nenhum evento aberto neste grupo.',
                            style: TextStyle(
                                color:
                                    Theme.of(routeContext).colorScheme.error),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey('event-$selectedGroupId'),
                          initialValue: currentEvent?.id,
                          decoration:
                              const InputDecoration(labelText: 'Evento'),
                          items: openEventsForGroup
                              .map((item) => DropdownMenuItem(
                                  value: item.id, child: Text(item.name)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              handleEventChange(value);
                            }
                          },
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AmountField(
                      controller: amountController,
                      autofocus: expense == null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Descricao'),
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
                    DropdownButtonFormField<String>(
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
                      DropdownButtonFormField<String>(
                        initialValue: singlePayerId,
                        decoration: const InputDecoration(labelText: 'Pagador'),
                        items: users
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
                        ...users
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
                    Text('Participantes',
                        style: Theme.of(routeContext).textTheme.titleSmall),
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
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.clear, size: 18),
                          label: const Text('Limpar'),
                          onPressed: () {
                            setState(() => selectedParticipants.clear());
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
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
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
                        children: [
                          Text('${selectedParticipants.length} participantes'),
                          if (totalShares > selectedParticipants.length)
                            Text('$totalShares cotas'),
                          if (shareValue == null)
                            const Text('Divisao: -')
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(totalShares > selectedParticipants.length
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
                    if (selectedParticipants.isEmpty)
                      const Text('Selecione ao menos um participante.')
                    else
                      ...users
                          .where(
                              (user) => selectedParticipants.contains(user.id))
                          .map(
                        (user) {
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
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      labelText: 'Historico da cota extra',
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
                    if (expense == null && currentEvent?.monthId != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      if (!showInstallments && !isSubscription) ...[
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => showInstallments = true),
                          icon: const Icon(Icons.event_repeat),
                          label: const Text('Parcelar essa despesa'),
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
                        KeyboardDoneBar(
                            child: TextField(
                          controller: installmentsController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Parcelas'),
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
                        const SizedBox(height: AppSpacing.xs),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            showInstallments = false;
                            installments = 1;
                            installmentsController.text = '1';
                          }),
                          icon: const Icon(Icons.close),
                          label: const Text('Não parcelar'),
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
                                    : 'Despesa parcelada'),
                            style: Theme.of(routeContext).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        expense.isSubscription
                            ? 'Essa despesa repete todo mês automaticamente até ser finalizada.'
                            : 'O número de parcelas não pode ser alterado depois de criada.',
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
                        onPressed: isSaving || currentEvent == null
                            ? null
                            : () => handleSave(),
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

/// Tela somente leitura para quem não é Adm nem cadastrou a despesa — pode
/// ver os detalhes, mas não tem acesso a nenhum campo editável ou ação de
/// excluir/salvar.
Future<void> _openExpenseDetails(
  BuildContext context,
  ExpenseModel expense,
) async {
  final installmentLabel = expense.installmentLabel;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (routeContext) => Scaffold(
        appBar: AppBar(title: const Text('Detalhes da despesa')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.description,
                    style: Theme.of(routeContext).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                MoneyText(expense.amount,
                    style: Theme.of(routeContext).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                _detailRow(
                    routeContext, 'Data', _formatDate(expense.expenseDate)),
                _detailRow(routeContext, 'Tipo de despesa', expense.category),
                if (installmentLabel != null)
                  _detailRow(routeContext, 'Parcela', installmentLabel),
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Text('Quem pagou',
                    style: Theme.of(routeContext).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                ...expense.payers.map((payer) => _detailRow(routeContext,
                    payer.nickname, formatCurrencyBRL(payer.amount))),
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Text('Participantes',
                    style: Theme.of(routeContext).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                ...expense.participants.map((participant) => _detailRow(
                    routeContext,
                    participant.shareCount > 1
                        ? '${participant.nickname} (x${participant.shareCount})'
                        : participant.nickname,
                    formatCurrencyBRL(participant.shareAmount))),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(routeContext).pop(),
                child: const Text('Fechar'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _detailRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
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

Future<List<UserOptionModel>> _loadEventUsers(
    WidgetRef ref, String groupId) async {
  final members = await ref.read(groupsRepositoryProvider).listMembers(groupId);
  return members
      .where((member) => member.active)
      .map((member) => UserOptionModel(
            id: member.userId,
            nickname: member.nickname,
            active: member.active,
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
