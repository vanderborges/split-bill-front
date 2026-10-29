import 'package:flutter/material.dart';

import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/event_model.dart';

/// Seletor de evento de Despesas/Relatório: na lista aberta cada item mostra
/// "evento | grupo" com a pílula de status à direita; o item selecionado
/// mostra o nome do evento com a pílula.
class EventPickerField extends StatelessWidget {
  const EventPickerField({
    super.key,
    required this.events,
    required this.selectedId,
    required this.groupNameOf,
    required this.onChanged,
    this.allEventsLabel,
  });

  final List<EventModel> events;
  final String? selectedId;
  final String Function(String groupId) groupNameOf;
  final ValueChanged<String?> onChanged;

  /// Com valor, a lista começa com um item "todos" (valor null) com esse
  /// texto — usado no Extrato ("Todos os eventos").
  final String? allEventsLabel;

  @override
  Widget build(BuildContext context) {
    final events = [...this.events]..sort(EventModel.compareSettlingFirst);
    final allLabel = allEventsLabel;
    return DropdownButtonFormField<String?>(
      dropdownColor: glassMenuColor(context),
      borderRadius: glassMenuRadius,
      menuMaxHeight: glassMenuMaxHeight,
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Evento'),
      // Selecionado: "Evento | Grupo" + a pílula de status.
      selectedItemBuilder: (context) => [
        if (allLabel != null) Text(allLabel),
        ...events.map((event) => Row(
              children: [
                Expanded(
                  child: Text('${event.name} | ${groupNameOf(event.groupId)}',
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
                      '${event.name} | ${groupNameOf(event.groupId)}',
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
