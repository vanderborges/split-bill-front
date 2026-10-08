import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/environment.dart';
import '../../../shared/api_error.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/auto_collapsing_fab.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../auth/services/auth_repository.dart';
import '../../events/models/event_model.dart';
import '../../events/services/events_repository.dart';
import '../models/group_invite_model.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';
import '../services/group_invite_repository.dart';
import '../services/groups_repository.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroupAsync = ref.watch(selectedGroupProvider);

    return AppScaffold(
      title: 'Grupos',
      floatingActionButton: AutoCollapsingFab(
        label: 'Novo grupo',
        onPressed: () => _showCreateGroupDialog(context, ref),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return const EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Nenhum grupo cadastrado.',
                  message: 'Crie um grupo para começar a dividir despesas.',
                );
              }
              final selectedId =
                  selectedGroupAsync.valueOrNull?.id ?? groups.first.id;
              final isSelectedGroupAdmin =
                  selectedGroupAsync.valueOrNull == null
                      ? false
                      : ref
                              .watch(groupRoleProvider(
                                  selectedGroupAsync.valueOrNull!.id))
                              .valueOrNull ==
                          'ADMIN';
              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedId,
                      decoration: const InputDecoration(labelText: 'Grupo'),
                      items: groups
                          .map((group) => DropdownMenuItem(
                              value: group.id, child: Text(group.name)))
                          .toList(),
                      onChanged: (value) {
                        ref.read(selectedGroupIdProvider.notifier).state =
                            value;
                        ref.invalidate(selectedGroupProvider);
                        ref.invalidate(eventsProvider);
                        ref.invalidate(selectedEventProvider);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar grupo',
                    onPressed: selectedGroupAsync.valueOrNull == null ||
                            !isSelectedGroupAdmin
                        ? null
                        : () => _showEditGroupDialog(
                            context, ref, selectedGroupAsync.valueOrNull!),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Deletar grupo',
                    onPressed: selectedGroupAsync.valueOrNull == null ||
                            !isSelectedGroupAdmin
                        ? null
                        : () => _deleteGroup(
                            context, ref, selectedGroupAsync.valueOrNull!),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ErrorState(
              message: friendlyApiError(error,
                  fallback: 'Não foi possível carregar seus grupos.'),
              onRetry: () => ref.invalidate(groupsProvider),
            ),
          ),
          const SizedBox(height: 16),
          selectedGroupAsync.when(
            data: (group) => group == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GroupReceiverSelector(group: group),
                      _GroupAutoSettlementSelector(group: group),
                      _GroupMembers(group: group),
                      _GroupTemporaryMembers(group: group),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorState(
              message: friendlyApiError(error,
                  fallback: 'Não foi possível carregar o grupo.'),
              onRetry: () => ref.invalidate(selectedGroupProvider),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _deleteGroup(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Excluir grupo'),
      content: Text(
          'Deseja realmente excluir o grupo "${group.name}"? Essa ação não pode ser desfeita.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await ref.read(groupsRepositoryProvider).delete(group.id);
    ref.read(selectedGroupIdProvider.notifier).state = null;
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(selectedEventProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível deletar o grupo.'))));
    }
  }
}

/// Admin-only: elege quem recebe os pagamentos deste grupo. Quando eleito,
/// a sugestão de pagamentos (na tela de Relatórios) manda todo devedor, em
/// qualquer evento do grupo, direto pra essa pessoa.
class _GroupReceiverSelector extends ConsumerWidget {
  const _GroupReceiverSelector({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGroupAdmin =
        ref.watch(groupRoleProvider(group.id)).valueOrNull == 'ADMIN';
    if (!isGroupAdmin) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<GroupMemberModel>>(
      future: ref.read(groupsRepositoryProvider).listMembers(group.id),
      builder: (context, snapshot) {
        final members = snapshot.data ?? <GroupMemberModel>[];
        final value =
            members.any((member) => member.userId == group.receiverUserId)
                ? group.receiverUserId
                : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String?>(
            key: ValueKey('receiver-${group.id}-$value'),
            initialValue: value,
            decoration: const InputDecoration(
                labelText: 'Quem recebe os pagamentos do grupo'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Ninguém eleito')),
              // Pessoa temporária não pode ser recebedora do grupo.
              ...members.where((member) => !member.temporary).map((member) =>
                  DropdownMenuItem<String?>(
                      value: member.userId, child: Text(member.nickname))),
            ],
            onChanged: (value) =>
                _setGroupReceiver(context, ref, group.id, value),
          ),
        );
      },
    );
  }
}

Future<void> _setGroupReceiver(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  String? userId,
) async {
  try {
    await ref
        .read(groupsRepositoryProvider)
        .setReceiver(groupId, userId: userId);
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível eleger o recebedor.'))),
      );
    }
  }
}

/// Admin-only: dia do mês em que o grupo abre automaticamente pra
/// pagamento o(s) evento(s) mensal(is) ainda abertos e já dispara o
/// alerta de cobrança — os mesmos dois passos que o admin faria na mão.
/// O fechamento definitivo continua manual (depende de todo mundo pagar).
class _GroupAutoSettlementSelector extends ConsumerWidget {
  const _GroupAutoSettlementSelector({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGroupAdmin =
        ref.watch(groupRoleProvider(group.id)).valueOrNull == 'ADMIN';
    if (!isGroupAdmin) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int?>(
            key: ValueKey(
                'auto-settlement-${group.id}-${group.autoSettlementDay}'),
            initialValue: group.autoSettlementDay,
            decoration: const InputDecoration(
                labelText: 'Fechamento automático (dia do mês)'),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('Desativado')),
              ...List.generate(31, (index) => index + 1).map((day) =>
                  DropdownMenuItem<int?>(value: day, child: Text('Dia $day'))),
            ],
            onChanged: (value) =>
                _setAutoSettlementDay(context, ref, group.id, value),
          ),
          const SizedBox(height: 4),
          Text(
            'No dia escolhido, o(s) evento(s) mensal(is) ainda aberto(s) '
            'deste grupo são abertos pra pagamento automaticamente e todo '
            'mundo recebe o aviso de cobrança. O fechamento definitivo '
            'continua manual, só depois que todos pagarem.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

Future<void> _setAutoSettlementDay(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  int? day,
) async {
  try {
    await ref
        .read(groupsRepositoryProvider)
        .setAutoSettlementDay(groupId, day: day);
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível salvar o fechamento automático.'))),
      );
    }
  }
}

class _GroupMembers extends ConsumerWidget {
  const _GroupMembers({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGroupAdmin =
        ref.watch(groupRoleProvider(group.id)).valueOrNull == 'ADMIN';
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    return FutureBuilder<List<GroupMemberModel>>(
      future: ref.watch(groupsRepositoryProvider).listMembers(group.id),
      builder: (context, snapshot) {
        final members = snapshot.data ?? <GroupMemberModel>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Integrantes',
                        style: Theme.of(context).textTheme.titleMedium)),
                if (isGroupAdmin)
                  TextButton.icon(
                    onPressed: () => _showInviteDialog(context, ref, group),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Convidar'),
                  ),
                if (currentUser != null)
                  TextButton.icon(
                    onPressed: () => _confirmLeaveGroup(context, ref, group),
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Sair'),
                  ),
              ],
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(),
            if (snapshot.hasError &&
                snapshot.connectionState == ConnectionState.done)
              ErrorState(
                message: friendlyApiError(snapshot.error!,
                    fallback: 'Não foi possível carregar os integrantes.'),
              )
            else if (members.isEmpty &&
                snapshot.connectionState == ConnectionState.done)
              const EmptyState(
                icon: Icons.person_add_alt_outlined,
                message: 'Nenhum integrante cadastrado.',
              )
            else
              ...members.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      PersonAvatar(name: member.nickname, seed: member.userId),
                  title: Text(member.nickname),
                  subtitle: Text(member.roleLabel),
                  trailing: isGroupAdmin && member.userId != currentUser?.id
                      ? Wrap(
                          children: [
                            if (!member.temporary)
                              IconButton(
                                tooltip: 'Alterar perfil no grupo',
                                icon:
                                    const Icon(Icons.manage_accounts_outlined),
                                onPressed: () => _showEditMemberRoleDialog(
                                    context, ref, group, member),
                              ),
                            IconButton(
                              tooltip: 'Remover integrante',
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () => _confirmRemoveMember(
                                  context, ref, group, member),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> _confirmRemoveMember(BuildContext context, WidgetRef ref,
    GroupModel group, GroupMemberModel member) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remover integrante'),
      content: Text('Deseja remover ${member.nickname} deste grupo?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await ref
        .read(groupsRepositoryProvider)
        .removeMember(group.id, member.userId);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(groupRoleProvider(group.id));
    ref.invalidate(groupsProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível remover o integrante.'))));
    }
  }
}

Future<void> _confirmLeaveGroup(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sair do grupo'),
      content: const Text(
          'Voce so pode sair se nao tiver saldo pendente em eventos abertos.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await ref.read(groupsRepositoryProvider).leave(group.id);
    ref.read(selectedGroupIdProvider.notifier).state = null;
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(selectedEventProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível sair do grupo.'))));
    }
  }
}

Future<void> _showEditMemberRoleDialog(BuildContext context, WidgetRef ref,
    GroupModel group, GroupMemberModel member) async {
  var role = member.role;
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Perfil de ${member.nickname}'),
        content: DropdownButtonFormField<String>(
          initialValue: role,
          decoration: const InputDecoration(labelText: 'Perfil no grupo'),
          items: const [
            DropdownMenuItem(value: 'MEMBER', child: Text('Integrante')),
            DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
          ],
          onChanged: (value) => setState(() => role = value ?? role),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salvar')),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  try {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) throw Exception('Sessao expirada');
    await ref.read(groupsRepositoryProvider).addMember(
          groupId: group.id,
          userId: member.userId,
          role: role,
        );
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(groupRoleProvider(group.id));
    ref.invalidate(groupsProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível alterar o perfil.'))));
    }
  }
}

Future<void> _showEditGroupDialog(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  final nameController = TextEditingController(text: group.name);
  final descriptionController =
      TextEditingController(text: group.description ?? '');
  final saved = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Editar grupo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome')),
          TextField(
              controller: descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descricao')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salvar')),
      ],
    ),
  );
  if (saved != true || !context.mounted) {
    nameController.dispose();
    descriptionController.dispose();
    return;
  }
  final name = nameController.text.trim();
  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um nome para o grupo.')));
    nameController.dispose();
    descriptionController.dispose();
    return;
  }
  try {
    await ref.read(groupsRepositoryProvider).update(
          groupId: group.id,
          name: name,
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível atualizar o grupo.'))));
    }
  } finally {
    nameController.dispose();
    descriptionController.dispose();
  }
}

Future<void> _showCreateGroupDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final saved = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Novo grupo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome')),
          TextField(
              controller: descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descricao')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salvar')),
      ],
    ),
  );
  if (saved != true || !context.mounted) {
    nameController.dispose();
    descriptionController.dispose();
    return;
  }
  try {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) throw Exception('Sessao expirada');
    final group = await ref.read(groupsRepositoryProvider).create(
          name: nameController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
    ref.read(selectedGroupIdProvider.notifier).state = group.id;
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível criar o grupo.'))));
    }
  } finally {
    nameController.dispose();
    descriptionController.dispose();
  }
}

Future<void> _showInviteDialog(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  GroupInviteModel invite;
  try {
    invite =
        await ref.read(groupInviteRepositoryProvider).getOrCreate(group.id);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível gerar o convite.'))));
    }
    return;
  }
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final url = '${Environment.webBaseUrl}/invite/${invite.id}';
        return AlertDialog(
          title: const Text('Convidar para o grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Envie este link para adicionar alguem ao grupo:'),
              const SizedBox(height: 12),
              SelectableText(url),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final regenerated = await ref
                    .read(groupInviteRepositoryProvider)
                    .regenerate(group.id);
                setState(() => invite = regenerated);
              },
              child: const Text('Gerar novo link'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado.')));
                }
              },
              child: const Text('Copiar link'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    ),
  );
}

/// Admin-only: pessoas temporárias — contas que entram no grupo só para um
/// evento (via convite temporário). Ficam aqui mesmo depois que o evento
/// fecha (aí ficam ocultas nas outras listas) para poderem ser reativadas
/// em outro evento.
class _GroupTemporaryMembers extends ConsumerStatefulWidget {
  const _GroupTemporaryMembers({required this.group});

  final GroupModel group;

  @override
  ConsumerState<_GroupTemporaryMembers> createState() =>
      _GroupTemporaryMembersState();
}

class _GroupTemporaryMembersState
    extends ConsumerState<_GroupTemporaryMembers> {
  Future<List<GroupMemberModel>>? _future;

  Future<List<GroupMemberModel>> _load() => _future ??=
      ref.read(groupsRepositoryProvider).listTemporaryMembers(widget.group.id);

  void _reload() {
    setState(() => _future = null);
    ref.invalidate(selectedGroupProvider);
  }

  @override
  void didUpdateWidget(_GroupTemporaryMembers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id) {
      _future = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGroupAdmin =
        ref.watch(groupRoleProvider(widget.group.id)).valueOrNull == 'ADMIN';
    if (!isGroupAdmin) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FutureBuilder<List<GroupMemberModel>>(
        future: _load(),
        builder: (context, snapshot) {
          final temporaries = snapshot.data ?? <GroupMemberModel>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('Pessoas temporárias',
                          style: Theme.of(context).textTheme.titleMedium)),
                  TextButton.icon(
                    onPressed: () =>
                        _showTemporaryInviteDialog(context, ref, widget.group),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Convidar temporário'),
                  ),
                ],
              ),
              Text(
                'Entram só para um evento e somem das listas quando ele fecha.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                ErrorState(
                  message: friendlyApiError(snapshot.error!,
                      fallback: 'Não foi possível carregar os temporários.'),
                  onRetry: _reload,
                )
              else
                ...temporaries.map(
                  (member) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Opacity(
                      opacity: member.temporaryEventClosed ? 0.5 : 1,
                      child: PersonAvatar(
                          name: member.nickname, seed: member.userId),
                    ),
                    title: Text(member.nickname),
                    subtitle: Text(member.temporaryEventName == null
                        ? 'Sem evento'
                        : member.temporaryEventClosed
                            ? '${member.temporaryEventName} (fechado — oculto)'
                            : member.temporaryEventName!),
                    trailing: IconButton(
                      tooltip: 'Incluir em outro evento',
                      icon: const Icon(Icons.event_repeat),
                      onPressed: () async {
                        final changed = await _assignTemporaryToEvent(
                            context, ref, widget.group, member);
                        if (changed) {
                          _reload();
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Pergunta em qual evento (não fechado) do grupo a pessoa temporária vai
/// entrar.
Future<EventModel?> _pickOpenEvent(
  BuildContext context,
  WidgetRef ref,
  String groupId, {
  required String title,
  String? excludeEventId,
}) async {
  final List<EventModel> events;
  try {
    events = (await ref.read(eventsRepositoryProvider).list(groupId: groupId))
        .where((event) => event.status != 'CLOSED')
        .where((event) => event.id != excludeEventId)
        .toList();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível carregar os eventos.'))));
    }
    return null;
  }
  if (!context.mounted) {
    return null;
  }
  if (events.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nenhum evento aberto disponível neste grupo.')));
    return null;
  }
  var selected = events.first;
  return showDialog<EventModel>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: DropdownButtonFormField<String>(
          initialValue: selected.id,
          decoration: const InputDecoration(labelText: 'Evento'),
          items: events
              .map((event) =>
                  DropdownMenuItem(value: event.id, child: Text(event.name)))
              .toList(),
          onChanged: (value) => setState(
              () => selected = events.firstWhere((event) => event.id == value)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('Continuar')),
        ],
      ),
    ),
  );
}

Future<void> _showTemporaryInviteDialog(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  final event = await _pickOpenEvent(context, ref, group.id,
      title: 'Convite temporário para qual evento?');
  if (event == null || !context.mounted) {
    return;
  }
  final GroupInviteModel invite;
  try {
    invite = await ref
        .read(groupInviteRepositoryProvider)
        .getOrCreateTemporary(group.id, event.id);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível gerar o convite.'))));
    }
    return;
  }
  if (!context.mounted) {
    return;
  }
  final url = '${Environment.webBaseUrl}/invite/${invite.id}';
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Convite temporário'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quem entrar por este link participa só do evento '
              '"${event.name}" (precisa ter ou criar uma conta):'),
          const SizedBox(height: 12),
          SelectableText(url),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Link copiado.')));
            }
          },
          child: const Text('Copiar link'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}

/// Reativa a pessoa temporária em outro evento. Retorna true se mudou.
Future<bool> _assignTemporaryToEvent(BuildContext context, WidgetRef ref,
    GroupModel group, GroupMemberModel member) async {
  final event = await _pickOpenEvent(
    context,
    ref,
    group.id,
    title: 'Incluir ${member.nickname} em qual evento?',
    excludeEventId:
        member.temporaryEventClosed ? null : member.temporaryEventId,
  );
  if (event == null || !context.mounted) {
    return false;
  }
  try {
    await ref.read(groupsRepositoryProvider).assignTemporaryEvent(
          groupId: group.id,
          userId: member.userId,
          eventId: event.id,
        );
    ref.invalidate(dashboardGroupBalancesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${member.nickname} agora participa de ${event.name}.')));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível incluir no evento.'))));
    }
    return false;
  }
}
