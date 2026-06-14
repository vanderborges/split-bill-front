import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
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
              const SnackBar(content: Text('Evento fechado nao permite novas despesas.')),
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: eventsAsync.when(
                  data: (events) => DropdownButtonFormField<String>(
                    value: event.id,
                    decoration: const InputDecoration(labelText: 'Evento'),
                    items: events
                        .map((item) => DropdownMenuItem(value: item.id, child: Text('${item.name} - ${item.typeLabel}')))
                        .toList(),
                    onChanged: (value) {
                      ref.read(selectedEventIdProvider.notifier).state = value;
                      ref.invalidate(selectedEventProvider);
                      ref.invalidate(selectedEventExpensesProvider);
                    },
                  ),
                  loading: () => Text('Evento ${event.name}', style: Theme.of(context).textTheme.titleMedium),
                  error: (_, __) => Text('Evento ${event.name}', style: Theme.of(context).textTheme.titleMedium),
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
                      return const Center(child: Text('Nenhuma despesa cadastrada.'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: expenses.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        return ListTile(
                          onTap: () async {
                            if (event.status == 'CLOSED') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Evento fechado nao permite editar despesas.')),
                              );
                              return;
                            }
                            final users = await _loadEventUsers(ref, event);
                            final categories = await _loadCategoryNames(ref);
                            if (context.mounted) {
                              await _showExpenseDialog(context, ref, event, users, categories, expense: expense);
                            }
                          },
                          title: Text(expense.description),
                          subtitle: Text('$groupName | ${event.name} | ${_expenseSubtitle(expense)}'),
                          trailing: Text(_formatMoney(expense.amount)),
                          onLongPress: () => _deleteExpense(context, ref, event, expense),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Erro ao carregar despesas: $error')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro ao carregar evento: $error')),
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

Future<void> _deleteExpense(BuildContext context, WidgetRef ref, EventModel event, ExpenseModel expense) async {
  try {
    final adminId = await _groupAdminId(ref, event.groupId);
    if (adminId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apenas admin do grupo pode deletar.')));
      return;
    }
    await ref.read(expensesRepositoryProvider).delete(expense.id, adminId);
    ref.invalidate(selectedEventExpensesProvider);
    ref.invalidate(selectedEventReportProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nao foi possivel deletar despesa: $error')));
    }
  }
}

Future<String?> _groupAdminId(WidgetRef ref, String groupId) async {
  final members = await ref.read(groupsRepositoryProvider).listMembers(groupId);
  final admins = members.where((member) => member.role == 'ADMIN').toList();
  return admins.isEmpty ? null : admins.first.userId;
}

Future<void> _createCurrentMonth(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  try {
    await ref.read(monthsRepositoryProvider).create(month: now.month, year: now.year);
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
}
) async {
  if (users.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cadastre ao menos um usuario antes de criar despesas.')),
    );
    return;
  }

  final descriptionController = TextEditingController(text: expense?.description ?? '');
  final amountController = TextEditingController(
    text: expense == null ? '' : expense.amount.toStringAsFixed(2).replaceAll('.', ','),
  );
  final categoryOptions = [...categories];
  var selectedCategory = categoryOptions.contains(expense?.category) ? expense!.category : categoryOptions.first;
  final selectedParticipants = expense == null
      ? users.map((user) => user.id).toSet()
      : expense.participants.map((participant) => participant.userId).toSet();
  var splitPaymentByUser = (expense?.payers.length ?? 0) > 1;
  final installmentsController = TextEditingController(text: '1');
  var installments = 1;
  var singlePayerId = expense == null || expense.payers.isEmpty ? users.first.id : expense.payers.first.userId;
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
          return AlertDialog(
            title: Text(expense == null ? 'Nova despesa' : 'Editar despesa'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descricao'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Tipo de despesa'),
                      items: categoryOptions
                          .map((category) => DropdownMenuItem(value: category, child: Text(category)))
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
                          final created = await _showCreateCategoryDialog(context, ref);
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
                        decoration: const InputDecoration(labelText: 'Parcelas'),
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
                      child: Text('Quem pagou', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    const SizedBox(height: 8),
                    if (!splitPaymentByUser)
                      DropdownButtonFormField<String>(
                        value: singlePayerId,
                        decoration: const InputDecoration(labelText: 'Pagador'),
                        items: users
                            .map((user) => DropdownMenuItem(value: user.id, child: Text(user.nickname)))
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: 'Valor pago por ${user.nickname}'),
                          ),
                        ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Participantes', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    ...users.map(
                      (user) => CheckboxListTile(
                        value: selectedParticipants.contains(user.id),
                        title: Text(user.nickname),
                        onChanged: (checked) {
                          setState(() {
                            if (checked ?? false) {
                              selectedParticipants.add(user.id);
                            } else {
                              selectedParticipants.remove(user.id);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salvar')),
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
    return;
  }

  if (!context.mounted) {
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    return;
  }

  final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
  final payerAmounts = splitPaymentByUser
      ? _readPayerAmounts(payerControllers)
      : amount == null
          ? <String, double>{}
          : {singlePayerId: amount};
  final installmentsToSave = int.tryParse(installmentsController.text.trim());
  final totalPaid = payerAmounts.values.fold<double>(0.0, (total, value) => total + value);
  if (descriptionController.text.trim().isEmpty ||
      amount == null ||
      selectedParticipants.isEmpty ||
      payerAmounts.isEmpty ||
      installmentsToSave == null ||
      installmentsToSave < 1 ||
      (totalPaid - amount).abs() > 0.009) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha descricao, valor, participantes e pagamentos somando o valor da despesa.'),
        ),
      );
    }
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    return;
  }
  if (installmentsToSave > 1 && splitPaymentByUser) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Despesa parcelada permite apenas um pagador.')),
    );
    descriptionController.dispose();
    amountController.dispose();
    installmentsController.dispose();
    _disposeControllers(payerControllers.values);
    return;
  }

  try {
    if (expense == null) {
      await ref.read(expensesRepositoryProvider).create(
            description: descriptionController.text.trim(),
            amount: amount,
            expenseDate: DateTime.now(),
            category: selectedCategory,
            monthId: event.monthId,
            eventId: event.id,
            participantIds: selectedParticipants.toList(),
            payerAmounts: payerAmounts,
            installments: installmentsToSave,
          );
    } else {
      await ref.read(expensesRepositoryProvider).update(
            id: expense.id,
            description: descriptionController.text.trim(),
            amount: amount,
            expenseDate: expense.expenseDate,
            category: selectedCategory,
            monthId: event.monthId,
            eventId: event.id,
            participantIds: selectedParticipants.toList(),
            payerAmounts: payerAmounts,
          );
    }
    ref.invalidate(currentMonthExpensesProvider);
    ref.invalidate(selectedEventExpensesProvider);
    ref.invalidate(currentMonthReportProvider);
    ref.invalidate(selectedEventReportProvider);
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
  }
}

Future<String?> _showCreateCategoryDialog(BuildContext context, WidgetRef ref) async {
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salvar')),
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
    final category = await ref.read(expenseCategoriesRepositoryProvider).create(name);
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
  final members = await ref.read(groupsRepositoryProvider).listMembers(event.groupId);
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

String _expenseSubtitle(ExpenseModel expense) {
  final installment = expense.installmentNumber == null
      ? ''
      : ' | Parcelado ${expense.installmentNumber}/${expense.totalInstallments}';
  return '${expense.category} | Pago por ${expense.payerNickname}$installment';
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

Map<String, double> _readPayerAmounts(Map<String, TextEditingController> controllers) {
  final result = <String, double>{};
  for (final entry in controllers.entries) {
    final value = double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0;
    if (value > 0) {
      result[entry.key] = value;
    }
  }
  return result;
}

void _disposeControllers(Iterable<TextEditingController> controllers) {
  for (final controller in controllers) {
    controller.dispose();
  }
}
