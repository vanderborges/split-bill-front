import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/api_error.dart';
import '../../../shared/widgets/amount_field.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../auth/services/auth_repository.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../events/models/event_model.dart';
import '../../events/services/events_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../../months/services/months_repository.dart';
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
    final openEventsAsync = ref.watch(openEventsProvider);
    final expensesAsync = ref.watch(selectedEventExpensesProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewExpenseFlow(context, ref),
        child: const Icon(Icons.add),
      ),
      child: eventAsync.when(
        data: (event) {
          if (event == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => _openNewExpenseFlow(context, ref),
                icon: const Icon(Icons.calendar_month),
                label: const Text('Criar mes atual e adicionar gasto'),
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
                child: openEventsAsync.when(
                  data: (openEvents) {
                    final items = [...openEvents];
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
              Expanded(
                child: expensesAsync.when(
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Nenhuma despesa cadastrada.',
                        message:
                            'Toque em "+" para registrar o primeiro gasto deste evento.',
                      );
                    }
                    final sortedExpenses = [...expenses]..sort((first, second) {
                        final firstIsInstallment =
                            first.installmentGroupId != null;
                        final secondIsInstallment =
                            second.installmentGroupId != null;
                        if (firstIsInstallment != secondIsInstallment) {
                          return firstIsInstallment ? 1 : -1;
                        }
                        final dateComparison =
                            second.expenseDate.compareTo(first.expenseDate);
                        if (dateComparison != 0) {
                          return dateComparison;
                        }
                        return first.description.compareTo(second.description);
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
                        final installmentLabel = _installmentLabel(expense);
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
                          onTap: !canChange
                              ? null
                              : () async {
                                  if (event.status == 'CLOSED') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Evento fechado nao permite editar despesas.')),
                                    );
                                    return;
                                  }
                                  final users =
                                      await _loadEventUsers(ref, event);
                                  final categories =
                                      await _loadCategoryNames(ref);
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

/// Fluxo único de "adicionar despesa": resolve o evento atual (criando o
/// mês corrente automaticamente se ainda não existir) e abre o formulário —
/// usado pelo FAB desta tela, pelo botão de estado vazio e pelo CTA "Nova
/// despesa" da Home (via [pendingAutoOpenExpenseProvider]), para que
/// nenhum desses pontos de entrada exija um segundo toque para chegar ao
/// formulário.
Future<void> _openNewExpenseFlow(BuildContext context, WidgetRef ref) async {
  var event = await ref.read(selectedEventProvider.future);
  if (!context.mounted) {
    return;
  }

  if (event == null) {
    final created = await _createCurrentMonth(context, ref);
    if (!created || !context.mounted) {
      return;
    }
    event = await ref.read(selectedEventProvider.future);
    if (!context.mounted || event == null) {
      return;
    }
  }

  if (event.status == 'CLOSED') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Evento fechado nao permite novas despesas.')),
    );
    return;
  }

  final users = await _loadEventUsers(ref, event);
  final categories = await _loadCategoryNames(ref);
  if (context.mounted) {
    await _openExpenseForm(context, ref, event, users, categories);
  }
}

Future<bool> _createCurrentMonth(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  try {
    await ref
        .read(monthsRepositoryProvider)
        .create(month: now.month, year: now.year);
    ref.invalidate(monthsProvider);
    ref.invalidate(currentMonthProvider);
    ref.invalidate(currentMonthExpensesProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(openEventsProvider);
    ref.invalidate(selectedEventProvider);
    ref.invalidate(selectedEventExpensesProvider);
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível criar o mês.'))),
      );
    }
    return false;
  }
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
  final selectedParticipants = expense == null
      ? users.map((user) => user.id).toSet()
      : expense.participants.map((participant) => participant.userId).toSet();
  final shareCountControllers = {
    for (final user in users)
      user.id: TextEditingController(
        text: _initialShareCount(user.id, expense),
      ),
  };
  final shareDescriptionControllers = {
    for (final user in users)
      user.id: TextEditingController(
        text: _initialShareDescription(user.id, expense),
      ),
  };
  var splitPaymentByUser = (expense?.payers.length ?? 0) > 1;
  final installmentsController = TextEditingController(text: '1');
  var installments = 1;
  var showInstallments = false;
  var isSaving = false;
  final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
  final defaultPayerId = users.any((user) => user.id == currentUserId)
      ? currentUserId!
      : users.first.id;
  var singlePayerId = expense == null || expense.payers.isEmpty
      ? defaultPayerId
      : expense.payers.first.userId;
  final payerControllers = {
    for (final user in users)
      user.id: TextEditingController(
        text: _initialPayerAmount(user.id, expense),
      ),
  };
  // Ao editar, só entra pré-selecionado quem de fato pagou algo (> 0) — não
  // faz sentido mostrar um campo de valor para cada integrante do grupo só
  // porque ele existe, como acontecia antes.
  final selectedPayerIds = <String>{
    if (expense != null)
      ...expense.payers
          .where((payer) => payer.amount > 0)
          .map((payer) => payer.userId),
  };

  void disposeControllers() {
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    _disposeControllers(shareCountControllers.values);
    _disposeControllers(shareDescriptionControllers.values);
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

          // Valida e salva sem fechar a tela: só sai (pop) em caso de
          // sucesso, pra não perder tudo que foi digitado quando algo dá
          // errado (validação local ou erro do backend).
          Future<void> handleSave() async {
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
                    content:
                        Text('Defina as cotas dos participantes selecionados.')),
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

            setState(() => isSaving = true);
            try {
              if (expense == null) {
                await ref.read(expensesRepositoryProvider).create(
                      description: descriptionController.text.trim(),
                      amount: amount,
                      expenseDate: selectedExpenseDate,
                      category: selectedCategory,
                      monthId: event.monthId,
                      eventId: event.id,
                      participantIds: selectedParticipants.toList(),
                      participantShareCounts: participantShareCounts,
                      participantShareDescriptions:
                          participantShareDescriptions,
                      payerAmounts: payerAmounts,
                      installments: installmentsToSave,
                    );
              } else {
                await ref.read(expensesRepositoryProvider).update(
                      id: expense.id,
                      description: descriptionController.text.trim(),
                      amount: amount,
                      expenseDate: selectedExpenseDate,
                      category: selectedCategory,
                      monthId: event.monthId,
                      eventId: event.id,
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
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AmountField(
                      controller: amountController,
                      autofocus: expense == null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: descriptionController,
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
                        decoration:
                            const InputDecoration(labelText: 'Pagador'),
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
                          label:
                              const Text('Dividir pagamento entre várias pessoas'),
                        ),
                      ],
                    ] else ...[
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: users.map((user) {
                          final selected =
                              selectedPayerIds.contains(user.id);
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
                      else
                        ...users
                            .where(
                                (user) => selectedPayerIds.contains(user.id))
                            .map(
                          (user) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AmountField(
                              controller: payerControllers[user.id]!,
                              label: 'Valor pago por ${user.nickname}',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
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
                                ..addAll(users.map((user) => user.id));
                              for (final user in users) {
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
                      children: users.map((user) {
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
                                                    style: Theme.of(routeContext)
                                                        .textTheme
                                                        .bodySmall),
                                                MoneyText(userAmount,
                                                    style: Theme.of(routeContext)
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
                                        ),
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
                    if (expense == null && event.monthId != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      if (!showInstallments)
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => showInstallments = true),
                          icon: const Icon(Icons.event_repeat),
                          label: const Text('Parcelar essa despesa'),
                        )
                      else ...[
                        TextField(
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
                        ),
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
                        onPressed: isSaving ? null : () => handleSave(),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
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
    WidgetRef ref, EventModel event) async {
  final members =
      await ref.read(groupsRepositoryProvider).listMembers(event.groupId);
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

/// Rótulo "1/3", "2/3"... para despesas parceladas — Etapa 12 do roteiro
/// de UX. Usa os campos `installmentNumber`/`totalInstallments` retornados
/// pela API (cada parcela vive em um mês/evento diferente, então não dá
/// para recalcular o total contando "irmãos" só na lista já carregada).
/// Despesas únicas (sem grupo, ou parceladas em 1x) não exibem rótulo.
String? _installmentLabel(ExpenseModel expense) {
  if (expense.installmentGroupId == null) {
    return null;
  }
  final total = expense.totalInstallments;
  final number = expense.installmentNumber;
  if (total == null || total <= 1 || number == null) {
    return null;
  }
  return 'Parcela $number/$total';
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
