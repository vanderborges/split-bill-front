import 'package:flutter/material.dart';

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
  });

  final List<EventModel> events;
  final String? selectedId;
  final String Function(String groupId) groupNameOf;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Evento'),
      // Selecionado: só o nome do evento + a pílula de status.
      selectedItemBuilder: (context) => events
          .map((event) => Row(
                children: [
                  Expanded(
                    child: Text(event.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  EventStatusBadge(event.status),
                ],
              ))
          .toList(),
      items: events
          .map((event) => DropdownMenuItem(
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
              ))
          .toList(),
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
