import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/services/auth_repository.dart';
import '../../events/services/events_repository.dart';
import '../../users/services/users_repository.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';
import '../services/groups_repository.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroupAsync = ref.watch(selectedGroupProvider);

    return AppScaffold(
      title: 'Grupos',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return const Text('Nenhum grupo cadastrado.');
              }
              final selectedId =
                  selectedGroupAsync.valueOrNull?.id ?? groups.first.id;
              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedId,
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
                    tooltip: 'Deletar grupo',
                    onPressed: selectedGroupAsync.valueOrNull == null
                        ? null
                        : () => _deleteGroup(
                            context, ref, selectedGroupAsync.valueOrNull!),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro ao carregar grupos: $error'),
          ),
          const SizedBox(height: 16),
          selectedGroupAsync.when(
            data: (group) => group == null
                ? const SizedBox.shrink()
                : _GroupMembers(group: group),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Erro ao carregar grupo: $error'),
          ),
        ],
      ),
    );
  }
}

Future<void> _deleteGroup(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  try {
    final members =
        await ref.read(groupsRepositoryProvider).listMembers(group.id);
    final admins = members.where((member) => member.role == 'ADMIN').toList();
    if (admins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apenas admin do grupo pode deletar.')));
      return;
    }
    await ref
        .read(groupsRepositoryProvider)
        .delete(group.id, admins.first.userId);
    ref.read(selectedGroupIdProvider.notifier).state = null;
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(selectedEventProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nao foi possivel deletar grupo: $error')));
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
                    onPressed: () => _showAddMemberDialog(context, ref, group),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Adicionar'),
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
            if (members.isEmpty &&
                snapshot.connectionState == ConnectionState.done)
              const Text('Nenhum integrante cadastrado.')
            else
              ...members.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(member.nickname),
                  subtitle: Text(member.roleLabel),
                  trailing: isGroupAdmin && member.userId != currentUser?.id
                      ? Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Alterar perfil no grupo',
                              icon: const Icon(Icons.manage_accounts_outlined),
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
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Nao foi possivel remover integrante: $error')));
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
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nao foi possivel sair do grupo: $error')));
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
          value: role,
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
          adminUserId: currentUser.id,
          userId: member.userId,
          role: role,
        );
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(groupRoleProvider(group.id));
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nao foi possivel alterar perfil: $error')));
    }
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
              decoration: const InputDecoration(labelText: 'Nome')),
          TextField(
              controller: descriptionController,
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
    final users = await ref.read(usersProvider.future);
    final admins = users.where((user) => user.admin).toList();
    if (admins.isEmpty) {
      throw Exception('Nenhum admin cadastrado');
    }
    final group = await ref.read(groupsRepositoryProvider).create(
          name: nameController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          adminUserId: admins.first.id,
        );
    ref.read(selectedGroupIdProvider.notifier).state = group.id;
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nao foi possivel criar grupo: $error')));
    }
  } finally {
    nameController.dispose();
    descriptionController.dispose();
  }
}

Future<void> _showAddMemberDialog(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  final users = await ref.read(usersProvider.future);
  if (!context.mounted || users.isEmpty) {
    return;
  }
  var userId = users.first.id;
  var role = 'MEMBER';
  final saved = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Adicionar integrante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: userId,
              decoration: const InputDecoration(labelText: 'Usuario'),
              items: users
                  .map((user) => DropdownMenuItem(
                      value: user.id, child: Text(user.nickname)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => userId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'Perfil no grupo'),
              items: const [
                DropdownMenuItem(value: 'MEMBER', child: Text('Integrante')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => role = value);
                }
              },
            ),
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
    ),
  );
  if (saved != true || !context.mounted) {
    return;
  }
  try {
    final members =
        await ref.read(groupsRepositoryProvider).listMembers(group.id);
    final admins = members.where((member) => member.role == 'ADMIN').toList();
    if (admins.isEmpty) {
      throw Exception('Nenhum admin no grupo');
    }
    await ref.read(groupsRepositoryProvider).addMember(
          groupId: group.id,
          adminUserId: admins.first.userId,
          userId: userId,
          role: role,
        );
    ref.invalidate(selectedGroupProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nao foi possivel adicionar: $error')));
    }
  }
}
