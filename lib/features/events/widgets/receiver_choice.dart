import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/person_avatar.dart';
import '../../groups/models/group_member_model.dart';
import '../../groups/services/groups_repository.dart';

/// "Fechar evento": quem vai receber os pagamentos deste evento. Uma pessoa
/// do evento (todo devedor paga pra ela) ou "Sugerir pagamentos" (o app
/// casa devedores com credores). Substituiu o "Quem recebe os pagamentos"
/// fixo da tela Grupos. [onChanged] recebe null para "Sugerir pagamentos".
class ReceiverChoice extends ConsumerStatefulWidget {
  const ReceiverChoice({
    super.key,
    required this.groupId,
    required this.eventId,
    required this.onChanged,
  });

  final String groupId;
  final String eventId;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<ReceiverChoice> createState() => _ReceiverChoiceState();
}

class _ReceiverChoiceState extends ConsumerState<ReceiverChoice> {
  late final Future<List<GroupMemberModel>> _members = ref
      .read(groupsRepositoryProvider)
      .listMembers(widget.groupId, eventId: widget.eventId);
  String? _selected;

  void _select(String? userId) {
    setState(() => _selected = userId);
    widget.onChanged(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Quem vai receber os pagamentos?',
            style: Theme.of(context).textTheme.titleSmall),
        _option(
          selected: _selected == null,
          leading: const Icon(Icons.lightbulb_outline),
          title: 'Sugerir pagamentos',
          subtitle: 'O app calcula e distribui quem paga quem.',
          onTap: () => _select(null),
        ),
        FutureBuilder<List<GroupMemberModel>>(
          future: _members,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            // Pessoa sem cadastro não tem PIX nem abre o app.
            final people = (snapshot.data ?? const <GroupMemberModel>[])
                .where((member) => member.active && !member.placeholder)
                .toList()
              ..sort((a, b) =>
                  a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()));
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: people
                  .map((member) => _option(
                        selected: _selected == member.userId,
                        leading: PersonAvatar(
                            name: member.nickname,
                            seed: member.userId,
                            radius: 14),
                        title: member.nickname,
                        onTap: () => _select(member.userId),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _option({
    required bool selected,
    required Widget leading,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      onTap: onTap,
    );
  }
}
