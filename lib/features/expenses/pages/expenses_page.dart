import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/services/auth_repository.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../events/models/event_model.dart';
import '../../events/services/events_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../../months/services/months_repository.dart';
import '../../reports/services/reports_repository.dart';
import '../../users/models/user_model.dart';
import '../../users/services/users_repository.dart';
import '../models/expense_model.dart';
import '../services/expense_categories_repository.dart';
import '../services/expenses_repository.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(selectedEventProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final expensesAsync = ref.watch(selectedEventExpensesProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    return AppScaffold(
      title: 'Despesas',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final event = await ref.read(selectedEventProvider.future);
          if (!context.mounted) {
            return;
          }
          if (event == null) {
            await _createCurrentMonth(context, ref);
            return;
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
            await _showExpenseDialog(context, ref, event, users, categories);
          }
        },
        child: const Icon(Icons.add),
      ),
      child: eventAsync.when(
        data: (event) {
          if (event == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => _createCurrentMonth(context, ref),
                icon: const Icon(Icons.calendar_month),
                label: const Text('Criar mes atual'),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: eventsAsync.when(
                  data: (events) => DropdownButtonFormField<String>(
                    initialValue: event.id,
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
                      ref.invalidate(selectedEventExpensesProvider);
                    },
                  ),
                  loading: () => Text('Evento ${event.name}',
                      style: Theme.of(context).textTheme.titleMedium),
                  error: (_, __) => Text('Evento ${event.name}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$groupName | ${event.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: expensesAsync.when(
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return const Center(
                          child: Text('Nenhuma despesa cadastrada.'));
                    }
                    final sortedExpenses = [...expenses]..sort((first, second) {
                        final dateComparison =
                            second.expenseDate.compareTo(first.expenseDate);
                        if (dateComparison != 0) {
                          return dateComparison;
                        }
                        return first.description.compareTo(second.description);
                      });
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
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
                        return ListTile(
                          leading: SizedBox(
                            width: 56,
                            child: Text(
                              _formatDate(expense.expenseDate),
                              textAlign: TextAlign.center,
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
                                    await _showExpenseDialog(
                                        context, ref, event, users, categories,
                                        expense: expense);
                                  }
                                },
                          title: Text(expense.description),
                          subtitle:
                              shareSummary == null ? null : Text(shareSummary),
                          trailing: Text(_formatMoney(expense.amount)),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Center(child: Text('Erro ao carregar despesas: $error')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar evento: $error')),
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
          SnackBar(content: Text('Nao foi possivel deletar despesa: $error')));
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

Future<void> _createCurrentMonth(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  try {
    await ref
        .read(monthsRepositoryProvider)
        .create(month: now.month, year: now.year);
    ref.invalidate(monthsProvider);
    ref.invalidate(currentMonthProvider);
    ref.invalidate(currentMonthExpensesProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(selectedEventProvider);
    ref.invalidate(selectedEventExpensesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel criar o mes: $error')),
      );
    }
  }
}

Future<void> _showExpenseDialog(
  BuildContext context,
  WidgetRef ref,
  EventModel event,
  List<UserModel> users,
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
        : expense.amount.toStringAsFixed(2).replaceAll('.', ','),
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

  final saved = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final totalShares =
              _totalShareCount(selectedParticipants, shareCountControllers);
          final dialogAmount =
              double.tryParse(amountController.text.replaceAll(',', '.'));
          final shareValue = dialogAmount == null || totalShares == 0
              ? null
              : dialogAmount / totalShares;

          return AlertDialog(
            title: Text(expense == null ? 'Nova despesa' : 'Editar despesa'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descricao'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
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
                    const SizedBox(height: 12),
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
                          final created =
                              await _showCreateCategoryDialog(context, ref);
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
                    const SizedBox(height: 12),
                    if (expense == null && event.monthId != null) ...[
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
                      const SizedBox(height: 12),
                    ],
                    SwitchListTile(
                      value: splitPaymentByUser,
                      title: const Text('Pagamento dividido por usuario?'),
                      onChanged: installments > 1
                          ? null
                          : (value) {
                              setState(() {
                                splitPaymentByUser = value;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Quem pagou',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    const SizedBox(height: 8),
                    if (!splitPaymentByUser)
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
                      )
                    else
                      ...users.map(
                        (user) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            controller: payerControllers[user.id],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                labelText: 'Valor pago por ${user.nickname}'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Participantes',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                          avatar: const Icon(Icons.person_outline, size: 18),
                          label: const Text('So pagador'),
                          onPressed: () {
                            setState(() {
                              selectedParticipants
                                ..clear()
                                ..add(singlePayerId);
                              final current =
                                  shareCountControllers[singlePayerId]!.text;
                              if ((int.tryParse(current) ?? 0) <= 0) {
                                shareCountControllers[singlePayerId]!.text =
                                    '1';
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          Text('${selectedParticipants.length} participantes'),
                          if (totalShares > selectedParticipants.length)
                            Text('$totalShares cotas'),
                          Text(shareValue == null
                              ? 'Divisao: -'
                              : totalShares > selectedParticipants.length
                                  ? 'Valor por cota: ${_formatMoney(shareValue)}'
                                  : 'Cada participante: ${_formatMoney(shareValue)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                            padding: const EdgeInsets.only(bottom: 12),
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
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge,
                                          ),
                                          if (userAmount != null)
                                            Text(
                                              'Participacao: ${_formatMoney(userAmount)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
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
                                  const SizedBox(height: 8),
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
                                  const SizedBox(height: 8),
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
                    if (expense != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final deleted = await _confirmDeleteExpense(
                              context,
                              ref,
                              expense,
                            );
                            if (deleted && context.mounted) {
                              Navigator.of(context).pop(false);
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
    },
  );

  if (saved != true) {
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    _disposeControllers(shareCountControllers.values);
    _disposeControllers(shareDescriptionControllers.values);
    return;
  }

  if (!context.mounted) {
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    _disposeControllers(shareCountControllers.values);
    _disposeControllers(shareDescriptionControllers.values);
    return;
  }

  final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
  final payerAmounts = splitPaymentByUser
      ? _readPayerAmounts(payerControllers)
      : amount == null
          ? <String, double>{}
          : {singlePayerId: amount};
  final installmentsToSave = int.tryParse(installmentsController.text.trim());
  final participantShareCounts =
      _readParticipantShareCounts(selectedParticipants, shareCountControllers);
  final participantShareDescriptions = _readParticipantShareDescriptions(
    selectedParticipants,
    shareDescriptionControllers,
  );
  final totalPaid =
      payerAmounts.values.fold<double>(0.0, (total, value) => total + value);
  if (descriptionController.text.trim().isEmpty ||
      amount == null ||
      selectedParticipants.isEmpty ||
      participantShareCounts.length != selectedParticipants.length ||
      payerAmounts.isEmpty ||
      installmentsToSave == null ||
      installmentsToSave < 1 ||
      (totalPaid - amount).abs() > 0.009) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Preencha descricao, valor, participantes e pagamentos somando o valor da despesa.'),
        ),
      );
    }
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    _disposeControllers(shareCountControllers.values);
    _disposeControllers(shareDescriptionControllers.values);
    return;
  }
  if (installmentsToSave > 1 && splitPaymentByUser) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Despesa parcelada permite apenas um pagador.')),
    );
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    _disposeControllers(shareCountControllers.values);
    _disposeControllers(shareDescriptionControllers.values);
    return;
  }

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
            participantShareDescriptions: participantShareDescriptions,
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
            participantShareDescriptions: participantShareDescriptions,
            payerAmounts: payerAmounts,
          );
    }
    ref.invalidate(currentMonthExpensesProvider);
    ref.invalidate(selectedEventExpensesProvider);
    ref.invalidate(currentMonthReportProvider);
    ref.invalidate(selectedEventReportProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(expense == null
              ? 'Despesa cadastrada com sucesso.'
              : 'Despesa atualizada com sucesso.'),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel salvar a despesa: $error')),
      );
    }
  } finally {
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    _disposeControllers(shareCountControllers.values);
    _disposeControllers(shareDescriptionControllers.values);
  }
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
        SnackBar(content: Text('Nao foi possivel criar o tipo: $error')),
      );
    }
    return null;
  }
}

Future<List<UserModel>> _loadEventUsers(WidgetRef ref, EventModel event) async {
  final users = await ref.read(usersProvider.future);
  final members =
      await ref.read(groupsRepositoryProvider).listMembers(event.groupId);
  final memberIds = members.map((member) => member.userId).toSet();
  return users.where((user) => memberIds.contains(user.id)).toList();
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

String _formatMoney(double value) {
  return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
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
    return '0';
  }
  final matching = expense.payers.where((payer) => payer.userId == userId);
  if (matching.isEmpty) {
    return '0';
  }
  return matching.first.amount.toStringAsFixed(2).replaceAll('.', ',');
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
    final value = double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0;
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
