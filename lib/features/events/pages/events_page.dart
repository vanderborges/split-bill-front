import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/api_error.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../expenses/services/expenses_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../../months/services/months_repository.dart';
import '../../reports/services/reports_repository.dart';
import '../models/event_model.dart';
import '../services/events_repository.dart';

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroupId = ref.watch(selectedGroupIdProvider);

    return AppScaffold(
      title: 'Eventos',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEventDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return const SizedBox.shrink();
                }
                final value = groups.any((group) => group.id == selectedGroupId)
                    ? selectedGroupId
                    : null;
                return DropdownButtonFormField<String>(
                  key: ValueKey(value),
                  initialValue: value,
                  decoration:
                      const InputDecoration(labelText: 'Filtrar por grupo'),
                  hint: const Text('Todos os grupos'),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('Todos os grupos')),
                    ...groups.map((group) => DropdownMenuItem(
                        value: group.id, child: Text(group.name))),
                  ],
                  onChanged: (value) {
                    ref.read(selectedGroupIdProvider.notifier).state = value;
                    ref.read(selectedEventIdProvider.notifier).state = null;
                    ref.invalidate(selectedEventProvider);
                    ref.invalidate(selectedEventExpensesProvider);
                    ref.invalidate(selectedEventReportProvider);
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                friendlyApiError(error,
                    fallback: 'Não foi possível carregar os grupos.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_outlined,
                    title: 'Nenhum evento cadastrado.',
                    message: 'Toque em "+" para criar um mês ou evento avulso.',
                  );
                }
                final groupsById = {
                  for (final group in groupsAsync.valueOrNull ?? [])
                    group.id: group,
                };
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final groupName =
                        groupsById[event.groupId]?.name ?? 'Grupo';
                    final isEventAdmin = ref
                            .watch(groupRoleProvider(event.groupId))
                            .valueOrNull ==
                        'ADMIN';
                    return Card(
                      child: ListTile(
                        title: Text(event.name),
                        subtitle: Padding(
                          padding:
                              const EdgeInsets.only(top: AppSpacing.xs),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.xs,
                            children: [
                              Text('$groupName | ${event.typeLabel}'),
                              StatusBadge(event.isClosed
                                  ? AppStatus.fechado
                                  : AppStatus.aberto),
                            ],
                          ),
                        ),
                        leading: Icon(event.isClosed
                            ? Icons.lock_outline
                            : Icons.event_available),
                        onTap: () {
                          ref.read(selectedEventIdProvider.notifier).state =
                              event.id;
                          context.go('/expenses');
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'expenses') {
                              ref.read(selectedEventIdProvider.notifier).state =
                                  event.id;
                              context.go('/expenses');
                            } else if (value == 'report') {
                              ref.read(selectedEventIdProvider.notifier).state =
                                  event.id;
                              context.go('/reports');
                            } else if (value == 'close') {
                              await _closeEvent(context, ref, event, events);
                            } else if (value == 'reopen') {
                              await _reopenEvent(context, ref, event);
                            } else if (value == 'delete') {
                              await _deleteEvent(context, ref, event);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'expenses', child: Text('Ver despesas')),
                            const PopupMenuItem(
                                value: 'report', child: Text('Ver relatorio')),
                            if (isEventAdmin && !event.isClosed)
                              const PopupMenuItem(
                                  value: 'close', child: Text('Fechar')),
                            if (isEventAdmin && event.isClosed)
                              const PopupMenuItem(
                                  value: 'reopen', child: Text('Reabrir')),
                            if (isEventAdmin)
                              const PopupMenuItem(
                                  value: 'delete', child: Text('Deletar')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingState(),
              error: (error, _) => ErrorState(
                message: friendlyApiError(error,
                    fallback: 'Não foi possível carregar os eventos.'),
                onRetry: () => ref.invalidate(eventsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showCreateEventDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final now = DateTime.now();
  final monthController = TextEditingController(text: now.month.toString());
  final yearController = TextEditingController(text: now.year.toString());
  var type = 'SPORADIC';
  String? selectedGroupId = ref.read(selectedGroupIdProvider);

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  Text('Novo evento',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.lg),
                  Text('O que você está criando?',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'MONTHLY',
                        label: Text('Mês do grupo'),
                        icon: Icon(Icons.calendar_month_outlined),
                      ),
                      ButtonSegment(
                        value: 'SPORADIC',
                        label: Text('Evento avulso'),
                        icon: Icon(Icons.celebration_outlined),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (selection) =>
                        setState(() => type = selection.first),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    type == 'MONTHLY'
                        ? 'Reúne as despesas do mês a mês do grupo e permite parcelamentos automáticos.'
                        : 'Uma ocasião pontual (viagem, festa, jantar). Sem parcelamento.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FutureBuilder(
                    future: ref.read(groupsProvider.future),
                    builder: (context, snapshot) {
                      final groups = snapshot.data ?? [];
                      if (groups.isEmpty) {
                        return const Text(
                            'Cadastre um grupo antes de criar eventos.');
                      }
                      if (selectedGroupId == null ||
                          groups
                              .every((group) => group.id != selectedGroupId)) {
                        selectedGroupId = groups.first.id;
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: selectedGroupId,
                        decoration: const InputDecoration(labelText: 'Grupo'),
                        items: groups
                            .map((group) => DropdownMenuItem(
                                value: group.id, child: Text(group.name)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedGroupId = value);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: type == 'MONTHLY' ? 'Nome (opcional)' : 'Nome',
                      hintText: type == 'MONTHLY'
                          ? '${now.month.toString().padLeft(2, '0')}/${now.year}'
                          : 'Ex.: Viagem para a praia',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: descriptionController,
                    decoration:
                        const InputDecoration(labelText: 'Descrição (opcional)'),
                  ),
                  if (type == 'MONTHLY') ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: monthController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Mes'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Ano'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  if (saved != true || !context.mounted) {
    nameController.dispose();
    descriptionController.dispose();
    monthController.dispose();
    yearController.dispose();
    return;
  }

  try {
    if (type == 'MONTHLY') {
      final month = int.tryParse(monthController.text.trim());
      final year = int.tryParse(yearController.text.trim());
      if (month == null ||
          month < 1 ||
          month > 12 ||
          year == null ||
          year < 2000) {
        throw Exception('Informe mes e ano validos');
      }
      final groups = await ref.read(groupsProvider.future);
      if (groups.isEmpty) {
        throw Exception('Nenhum grupo cadastrado');
      }
      final groupId = selectedGroupId ?? groups.first.id;
      final event = await ref.read(eventsRepositoryProvider).create(
            name: nameController.text.trim().isEmpty
                ? '${month.toString().padLeft(2, '0')}/$year'
                : nameController.text.trim(),
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            type: type,
            month: month,
            year: year,
            groupId: groupId,
          );
      ref.read(selectedEventIdProvider.notifier).state = event.id;
      ref.invalidate(monthsProvider);
    } else {
      final groups = await ref.read(groupsProvider.future);
      if (groups.isEmpty) {
        throw Exception('Nenhum grupo cadastrado');
      }
      final groupId = selectedGroupId ?? groups.first.id;
      final event = await ref.read(eventsRepositoryProvider).create(
            name: nameController.text.trim(),
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            type: type,
            groupId: groupId,
          );
      ref.read(selectedEventIdProvider.notifier).state = event.id;
    }
    ref.read(selectedGroupIdProvider.notifier).state = selectedGroupId;
    _invalidateEventState(ref);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(error,
              fallback: 'Não foi possível criar o evento.'))));
    }
  } finally {
    nameController.dispose();
    descriptionController.dispose();
    monthController.dispose();
    yearController.dispose();
  }
}

Future<void> _closeEvent(
  BuildContext context,
  WidgetRef ref,
  EventModel event,
  List<EventModel> events,
) async {
  String? targetId;
  final targets = events
      .where((item) => item.id != event.id && item.status == 'OPEN')
      .toList();
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Fechar ${event.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Voce pode fechar apenas ou consolidar o saldo como despesa em outro evento.'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: targetId,
                  decoration: const InputDecoration(labelText: 'Consolidar em'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Fechar apenas')),
                    ...targets.map((target) => DropdownMenuItem<String?>(
                        value: target.id, child: Text(target.name))),
                  ],
                  onChanged: (value) => setState(() => targetId = value),
                ),
              ],
            ),
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
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await ref
        .read(eventsRepositoryProvider)
        .close(event.id, consolidateToEventId: targetId);
    _invalidateEventState(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento fechado com sucesso.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(error,
              fallback: 'Não foi possível fechar o evento.'))));
    }
  }
}

Future<void> _reopenEvent(
    BuildContext context, WidgetRef ref, EventModel event) async {
  try {
    await ref.read(eventsRepositoryProvider).reopen(event.id);
    _invalidateEventState(ref);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(error,
              fallback: 'Não foi possível reabrir o evento.'))));
    }
  }
}

Future<void> _deleteEvent(
    BuildContext context, WidgetRef ref, EventModel event) async {
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Deletar evento'),
      content: Text('Deseja deletar ${event.name}?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deletar')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    await ref.read(eventsRepositoryProvider).delete(event.id);
    _invalidateEventState(ref);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(error,
              fallback: 'Não foi possível deletar o evento.'))));
    }
  }
}

void _invalidateEventState(WidgetRef ref) {
  ref.invalidate(eventsProvider);
  ref.invalidate(selectedEventProvider);
  ref.invalidate(selectedEventExpensesProvider);
  ref.invalidate(selectedEventReportProvider);
  ref.invalidate(dashboardGroupBalancesProvider);
}
