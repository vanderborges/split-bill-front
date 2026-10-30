import 'package:flutter/material.dart';

import '../../../shared/ptbr_sort.dart';
import '../../../shared/widgets/glass_dropdown_field.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/event_model.dart';

/// Seletor de evento de Despesas/Relatório: na lista aberta cada item mostra
/// "grupo | evento" com a pílula de status à direita; o item selecionado
/// mostra o nome do evento com a pílula.
class EventPickerField extends StatelessWidget {
  const EventPickerField({
    super.key,
    required this.events,
    required this.selectedId,
    required this.groupNameOf,
    required this.onChanged,
    this.allEventsLabel,
    this.sortByGroup = false,
    this.showGroupName = true,
  });

  final List<EventModel> events;
  final String? selectedId;
  final String Function(String groupId) groupNameOf;
  final ValueChanged<String?> onChanged;

  /// Com valor, a lista começa com um item "todos" (valor null) com esse
  /// texto — usado no Extrato ("Todos os eventos").
  final String? allEventsLabel;

  /// Extrato: lista agrupada pelo nome do grupo (A-Z); dentro de cada
  /// grupo mantém a ordem de sempre ([EventModel.compareSettlingFirst]).
  final bool sortByGroup;

  /// false (Despesas/Saldo): só o nome do evento, sem "Grupo | ".
  final bool showGroupName;

  String _label(EventModel event) => showGroupName
      ? '${groupNameOf(event.groupId)} | ${event.name}'
      : event.name;

  @override
  Widget build(BuildContext context) {
    final events = [...this.events]..sort((first, second) {
        if (sortByGroup) {
          final byGroup = compareNamesPtBr(
              groupNameOf(first.groupId), groupNameOf(second.groupId));
          if (byGroup != 0) {
            return byGroup;
          }
        }
        return EventModel.compareSettlingFirst(first, second);
      });
    final allLabel = allEventsLabel;
    return GlassDropdownField<String?>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Evento'),
      // Selecionado: "Grupo | Evento" + a pílula de status.
      selectedItemBuilder: (context) => [
        if (allLabel != null) Text(allLabel),
        ...events.map((event) => Row(
              children: [
                Expanded(
                  child: Text(_label(event),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                EventStatusBadge(event.status),
              ],
            )),
      ],
      items: [
        if (allLabel != null)
          DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
        ...events.map((event) => DropdownMenuItem<String?>(
              value: event.id,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(event),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  EventStatusBadge(event.status),
                ],
              ),
            )),
      ],
      onChanged: onChanged,
    );
  }
}

class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(switch (status) {
      'CLOSED' => AppStatus.fechado,
      'SETTLING' => AppStatus.aguardandoPagamento,
      _ => AppStatus.aberto,
    });
  }
}
