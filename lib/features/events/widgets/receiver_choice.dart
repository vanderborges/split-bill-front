import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/person_avatar.dart';
import '../../groups/models/group_member_model.dart';
import '../../groups/services/groups_repository.dart';
import '../../reports/models/monthly_report_model.dart';
import '../../reports/services/reports_repository.dart';

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
  // A pessoa já escolheu: a sugestão inicial não sobrescreve mais.
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _preselectTopCreditor();
  }

  /// Abre com o participante de maior saldo positivo já marcado (sem
  /// ninguém positivo, fica em "Sugerir pagamentos"). Só a seleção inicial
  /// muda; a escolha continua livre.
  Future<void> _preselectTopCreditor() async {
    try {
      final results = await Future.wait([
        _members,
        ref.read(reportsRepositoryProvider).getEventReport(widget.eventId),
      ]);
      final members = results[0] as List<GroupMemberModel>;
      final report = results[1] as MonthlyReportModel;
      final eligible = _eligible(members).map((m) => m.userId).toSet();
      final creditors = report.balances
          .where((b) => b.balance > 0 && eligible.contains(b.userId))
          .toList()
        ..sort((a, b) => b.balance.compareTo(a.balance));
      if (creditors.isEmpty || !mounted || _touched) {
        return;
      }
      setState(() => _selected = creditors.first.userId);
      widget.onChanged(creditors.first.userId);
    } catch (_) {
      // Sem saldo, fica em "Sugerir pagamentos" como antes.
    }
  }

  // Pessoa sem cadastro não tem PIX nem abre o app.
  List<GroupMemberModel> _eligible(List<GroupMemberModel> members) =>
      members.where((member) => member.active && !member.placeholder).toList();

  void _select(String? userId) {
    _touched = true;
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
            final people = _eligible(
                snapshot.data ?? const <GroupMemberModel>[])
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
