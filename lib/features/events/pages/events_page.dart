import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/api_error.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/auto_collapsing_fab.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/keyboard_done_bar.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../expenses/services/expenses_repository.dart';
import '../../groups/models/group_model.dart';
import '../../groups/pages/groups_page.dart' show showTemporaryGuestDialog;
import '../../groups/services/groups_repository.dart';
import '../../months/services/months_repository.dart';
import '../../reports/pages/reports_page.dart' show confirmStartSettlement;
import '../../reports/services/reports_repository.dart';
import '../models/event_model.dart';
import '../services/events_repository.dart';
import '../services/new_event_intent.dart';

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final hideClosed = ref.watch(hideClosedEventsProvider);

    if (ref.read(pendingAutoOpenEventProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        if (!ref.read(pendingAutoOpenEventProvider)) {
          return;
        }
        ref.read(pendingAutoOpenEventProvider.notifier).state = false;
        _showCreateEventDialog(context, ref);
      });
    }

    return AppScaffold(
      title: 'Eventos',
      floatingActionButton: AutoCollapsingFab(
        label: 'Novo evento',
        onPressed: () => _showCreateEventDialog(context, ref),
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
                  dropdownColor: glassMenuColor(context),
                  borderRadius: glassMenuRadius,
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
          CheckboxListTile(
            value: hideClosed,
            onChanged: (value) => ref
                .read(hideClosedEventsProvider.notifier)
                .state = value ?? false,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Ocultar fechados'),
          ),
          Expanded(
            child: eventsAsync.when(
              data: (allEvents) {
                // Abertos primeiro, depois aguardando pagamento, depois
                // fechados; dentro de cada um, do mais recente pro mais
                // antigo.
                int statusRank(EventModel event) =>
                    event.isOpen ? 0 : (event.isSettling ? 1 : 2);
                final events = (hideClosed
                    ? allEvents.where((event) => !event.isClosed).toList()
                    : [...allEvents])
                  ..sort((a, b) {
                    final byStatus = statusRank(a).compareTo(statusRank(b));
                    if (byStatus != 0) {
                      return byStatus;
                    }
                    final byDate = b.sortDate.compareTo(a.sortDate);
                    if (byDate != 0) {
                      return byDate;
                    }
                    return (b.createdAt ?? DateTime(0))
                        .compareTo(a.createdAt ?? DateTime(0));
                  });
                if (events.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_outlined,
                    title: allEvents.isEmpty
                        ? 'Nenhum evento cadastrado.'
                        : 'Nenhum evento aberto.',
                    message: allEvents.isEmpty
                        ? 'Toque em "+" para criar um mês ou evento avulso.'
                        : 'Desmarque "Ocultar fechados" para ver todos.',
                  );
                }
                final groupsById = {
                  for (final group in groupsAsync.valueOrNull ?? [])
                    group.id: group,
                };
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      16, 16, 16, fabClearance + bottomBarInset(context)),
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
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.xs,
                            children: [
                              Text('$groupName | ${event.typeLabel}'),
                              StatusBadge(event.isClosed
                                  ? AppStatus.fechado
                                  : event.isSettling
                                      ? AppStatus.aguardandoPagamento
                                      : AppStatus.aberto),
                            ],
                          ),
                        ),
                        leading: Icon(event.isClosed
                            ? Icons.lock_outline
                            : event.isSettling
                                ? Icons.hourglass_top_outlined
                                : Icons.event_available),
                        onTap: () {
                          selectEvent(ref,
                              groupId: event.groupId, eventId: event.id);
                          context.go('/expenses');
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'expenses') {
                              selectEvent(ref,
                                  groupId: event.groupId, eventId: event.id);
                              context.go('/expenses');
                            } else if (value == 'report') {
                              selectEvent(ref,
                                  groupId: event.groupId, eventId: event.id);
                              context.go('/expenses?view=saldo');
                            } else if (value == 'start-settlement') {
                              await confirmStartSettlement(
                                  context, ref, event.groupId, event.id);
                            } else if (value == 'close') {
                              await _closeEvent(context, ref, event);
                            } else if (value == 'reopen') {
                              await _reopenEvent(context, ref, event);
                            } else if (value == 'add-temporary') {
                              await showTemporaryGuestDialog(
                                  context, ref, event.groupId);
                            } else if (value == 'delete') {
                              await _deleteEvent(context, ref, event);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'expenses', child: Text('Ver despesas')),
                            const PopupMenuItem(
                                value: 'report', child: Text('Ver saldo')),
                            if (isEventAdmin && event.isOpen)
                              const PopupMenuItem(
                                  value: 'start-settlement',
                                  child: Text('Fechar evento')),
                            if (isEventAdmin && event.isSettling)
                              const PopupMenuItem(
                                  value: 'close',
                                  child: Text('Concluir evento')),
                            if (isEventAdmin && !event.isOpen)
                              const PopupMenuItem(
                                  value: 'reopen', child: Text('Reabrir')),
                            if (isEventAdmin && !event.isClosed)
                              const PopupMenuItem(
                                  value: 'add-temporary',
                                  child: Text('Incluir temporário')),
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

/// Mês/ano seguinte ao último evento mensal do grupo, ou o mês atual se o
/// grupo ainda não tem nenhum evento mensal. `locked` = já existe um evento
/// mensal aberto no grupo: aí o próximo tem que ser exatamente esse mês
/// (o backend também exige) e o campo fica travado.
Future<(int, int, bool)> _nextMonthlyReference(
    WidgetRef ref, String groupId) async {
  final events =
      await ref.read(eventsRepositoryProvider).list(groupId: groupId);
  final monthly = events
      .where((event) =>
          event.type == 'MONTHLY' && event.month != null && event.year != null)
      .toList();
  if (monthly.isEmpty) {
    final now = DateTime.now();
    return (now.month, now.year, false);
  }
  final last = monthly.reduce(
      (a, b) => a.year! * 12 + a.month! >= b.year! * 12 + b.month! ? a : b);
  final locked = monthly.any((event) => event.isOpen);
  return last.month == 12
      ? (1, last.year! + 1, locked)
      : (last.month! + 1, last.year!, locked);
}

Future<void> _showCreateEventDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final now = DateTime.now();
  final monthController = TextEditingController(text: now.month.toString());
  final yearController = TextEditingController(text: now.year.toString());
  var type = 'SPORADIC';
  // Com um mês do grupo já aberto, o tipo padrão vira "Mês do grupo" —
  // até a pessoa escolher o tipo à mão.
  var typeTouched = false;
  String? nameError;
  String? selectedGroupId = ref.read(selectedGroupIdProvider);

  // Sugere no campo Mes/Ano o mes seguinte ao ultimo evento mensal ja
  // cadastrado no grupo (cai no mes atual se o grupo ainda nao tem
  // nenhum). So sobrescreve se o usuario ainda nao mexeu nos campos.
  var suggestedMonth = monthController.text;
  var suggestedYear = yearController.text;
  var monthLocked = false;
  Future<void> suggestNextMonth(String? groupId) async {
    if (groupId == null) {
      return;
    }
    try {
      final (month, year, locked) = await _nextMonthlyReference(ref, groupId);
      monthLocked = locked;
      if (!typeTouched) {
        type = locked ? 'MONTHLY' : 'SPORADIC';
      }
      if (!locked &&
          (monthController.text != suggestedMonth ||
              yearController.text != suggestedYear)) {
        return;
      }
      suggestedMonth = month.toString();
      suggestedYear = year.toString();
      monthController.text = suggestedMonth;
      yearController.text = suggestedYear;
    } catch (_) {
      // Sem sugestao: mantem o mes atual.
      monthLocked = false;
    }
  }

  final initialGroups =
      await ref.read(groupsProvider.future).catchError((_) => <GroupModel>[]);
  if (selectedGroupId == null && initialGroups.isNotEmpty) {
    selectedGroupId = initialGroups.first.id;
  }
  await suggestNextMonth(selectedGroupId);
  if (!context.mounted) {
    nameController.dispose();
    monthController.dispose();
    yearController.dispose();
    return;
  }

  // Mês/Ano usam o teclado numérico com a barra "OK" por cima dele: os
  // botões sobem também a altura dessa barra.
  final monthFocus = FocusNode();
  final yearFocus = FocusNode();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return ListenableBuilder(
        listenable: Listenable.merge([monthFocus, yearFocus]),
        builder: (context, child) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          final doneBar =
              keyboard > 0 && (monthFocus.hasFocus || yearFocus.hasFocus)
                  ? 44.0
                  : 0.0;
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard + doneBar),
            child: child,
          );
        },
        child: StatefulBuilder(
          builder: (context, setState) {
            // Só os campos rolam; Cancelar/Salvar ficam presos embaixo,
            // logo acima do teclado (antes rolavam junto e ficavam atrás
            // dele).
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.outline,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
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
                          onSelectionChanged: (selection) => setState(() {
                            type = selection.first;
                            typeTouched = true;
                          }),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          type == 'MONTHLY'
                              ? 'Reúne as despesas mês a mês do grupo e permite parcelamentos automáticos.'
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
                                groups.every(
                                    (group) => group.id != selectedGroupId)) {
                              selectedGroupId = groups.first.id;
                            }
                            return DropdownButtonFormField<String>(
                              dropdownColor: glassMenuColor(context),
                              borderRadius: glassMenuRadius,
                              initialValue: selectedGroupId,
                              decoration:
                                  const InputDecoration(labelText: 'Grupo'),
                              items: groups
                                  .map((group) => DropdownMenuItem(
                                      value: group.id, child: Text(group.name)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => selectedGroupId = value);
                                  suggestNextMonth(value).then((_) {
                                    if (context.mounted) setState(() {});
                                  });
                                }
                              },
                            );
                          },
                        ),
                        // Evento mensal se chama sempre pelo mês (MM/AAAA), então
                        // só o avulso pede nome.
                        if (type != 'MONTHLY') ...[
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: nameController,
                            maxLength: 50,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Nome',
                              hintText: 'Ex.: Viagem para a praia',
                              errorText: nameError,
                            ),
                            onChanged: (_) {
                              if (nameError != null) {
                                setState(() => nameError = null);
                              }
                            },
                            autofocus: true,
                          ),
                        ],
                        if (type == 'MONTHLY' && monthLocked) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Já existe um mês aberto, então o próximo segue a ordem dos meses e já nasce com as parcelas e assinaturas do mês anterior.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (type == 'MONTHLY' && !monthLocked) ...[
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: KeyboardDoneBar(
                                    child: TextField(
                                  controller: monthController,
                                  focusNode: monthFocus,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      const InputDecoration(labelText: 'Mês'),
                                )),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: KeyboardDoneBar(
                                    child: TextField(
                                  controller: yearController,
                                  focusNode: yearFocus,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      const InputDecoration(labelText: 'Ano'),
                                )),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Row(
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
                          onPressed: () {
                            if (type != 'MONTHLY' &&
                                nameController.text.trim().isEmpty) {
                              setState(() =>
                                  nameError = 'Informe o nome do evento.');
                              return;
                            }
                            Navigator.of(context).pop(true);
                          },
                          child: Text(type == 'MONTHLY' && monthLocked
                              ? 'Criar mês ${monthController.text.padLeft(2, '0')}/${yearController.text}'
                              : 'Salvar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
  // Depois da animação de saída: os campos ainda usam os FocusNodes
  // enquanto o sheet desce.
  Future.delayed(const Duration(milliseconds: 600), () {
    monthFocus.dispose();
    yearFocus.dispose();
  });

  if (saved != true || !context.mounted) {
    nameController.dispose();
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
        throw const FormatException('Informe mês e ano válidos.');
      }
      final groups = await ref.read(groupsProvider.future);
      if (groups.isEmpty) {
        throw Exception('Nenhum grupo cadastrado');
      }
      final groupId = selectedGroupId ?? groups.first.id;
      final event = await ref.read(eventsRepositoryProvider).create(
            name: '${month.toString().padLeft(2, '0')}/$year',
            type: type,
            month: month,
            year: year,
            groupId: groupId,
          );
      selectEvent(ref, groupId: event.groupId, eventId: event.id);
      ref.invalidate(monthsProvider);
    } else {
      final groups = await ref.read(groupsProvider.future);
      if (groups.isEmpty) {
        throw Exception('Nenhum grupo cadastrado');
      }
      final groupId = selectedGroupId ?? groups.first.id;
      final event = await ref.read(eventsRepositoryProvider).create(
            name: nameController.text.trim(),
            type: type,
            groupId: groupId,
          );
      selectEvent(ref, groupId: event.groupId, eventId: event.id);
    }
    _invalidateEventState(ref);
    // Evento novo abre direto nas despesas dele.
    if (context.mounted) {
      context.go('/expenses');
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is FormatException
              ? error.message
              : friendlyApiError(error,
                  fallback: 'Não foi possível criar o evento.'))));
    }
  } finally {
    nameController.dispose();
    monthController.dispose();
    yearController.dispose();
  }
}

/// Fechamento definitivo, depois de todos os pagamentos confirmados na tela
/// de acertos. Backend bloqueia se ainda houver pendencia.
Future<void> _closeEvent(
  BuildContext context,
  WidgetRef ref,
  EventModel event,
) async {
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Concluir ${event.name}'),
      content: const Text(
          'Confirma que todos os pagamentos já foram acertados? Depois de concluído, o evento não pode mais ser alterado.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Concluir')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await ref.read(eventsRepositoryProvider).close(event.id);
    _invalidateEventState(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento concluído com sucesso.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível concluir o evento.'))));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
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
