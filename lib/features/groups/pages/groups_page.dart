import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/routes/navigation_history.dart';
import '../../../core/constants/environment.dart';
import '../../../shared/api_error.dart';
import '../../../shared/ptbr_sort.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/glass_dropdown_field.dart';
import '../../../shared/widgets/glass_search_field.dart';
import '../../../shared/widgets/pinned_header.dart';
import '../../../shared/widgets/auto_collapsing_fab.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../dashboard/services/dashboard_repository.dart';
import '../../auth/services/auth_repository.dart';
import '../../events/services/events_repository.dart';
import '../models/group_invite_model.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';
import '../services/group_invite_repository.dart';
import '../services/groups_repository.dart';
import '../services/create_group_intent.dart';

/// Texto da busca da tela Grupos (zera ao sair da tela).
final groupsSearchProvider = StateProvider.autoDispose<String>((ref) => '');

/// Texto da busca de participantes do grupo.
final groupMembersSearchProvider =
    StateProvider.autoDispose<String>((ref) => '');

/// Grupos (aba da barra): lista dos grupos de quem está logado, no padrão
/// da tela Eventos. Tocar num grupo abre os participantes dele
/// ([GroupDetailPage], `/groups/{id}`).
class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    // Veio do aviso "crie um grupo primeiro" (Eventos/Início).
    if (ref.read(pendingCreateGroupProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !ref.read(pendingCreateGroupProvider)) {
          return;
        }
        ref.read(pendingCreateGroupProvider.notifier).state = false;
        _showCreateGroupDialog(context, ref);
      });
    }

    return AppScaffold(
      scrollsBehindTopBar: true,
      title: 'Grupos',
      floatingActionButton: AutoCollapsingFab(
        label: 'Novo grupo',
        onPressed: () => _showCreateGroupDialog(context, ref),
      ),
      child: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Nenhum grupo cadastrado.',
                  message:
                      'Toque em "+" para criar um grupo e começar a dividir despesas.',
                ),
              ),
            );
          }
          final query = ref.watch(groupsSearchProvider);
          // Grupos em ordem alfabética (sem acento/caixa).
          final filtered = sortedByNamePtBr(
              groups.where((group) => matchesSearchPtBr(group.name, query)),
              (group) => group.name);
          // Campo de busca fixo no topo; a lista rola por trás dele.
          return PinnedHeaderLayout(
            header: AppSearchField(
              hint: 'Buscar grupo',
              onChanged: (value) =>
                  ref.read(groupsSearchProvider.notifier).state = value,
            ),
            builder: (context, top) {
              final padding = EdgeInsets.fromLTRB(
                  16, top, 16, fabClearance + bottomBarInset(context));
              return filtered.isEmpty
                  ? ListView(padding: padding, children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text('Nenhum grupo encontrado.',
                            textAlign: TextAlign.center),
                      ),
                    ])
                  : ListView.separated(
                      padding: padding,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final group = filtered[index];
                        // Card mais alto que o de Eventos: o grupo é o destaque.
                        return Card(
                          child: ListTile(
                            minVerticalPadding: 20,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            leading:
                                const Icon(Icons.groups_outlined, size: 32),
                            // Sem negrito no nome do grupo.
                            title: Text(group.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w400)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                openGroupDetail(context, ref, group.id),
                          ),
                        );
                      },
                    );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: friendlyApiError(error,
              fallback: 'Não foi possível carregar seus grupos.'),
          onRetry: () => ref.invalidate(groupsProvider),
        ),
      ),
    );
  }
}

/// Abre os participantes do grupo; grava o grupo como selecionado (as
/// outras telas abrem nele, como antes com o seletor de Grupos).
void openGroupDetail(BuildContext context, WidgetRef ref, String groupId) {
  if (ref.read(selectedGroupIdProvider) != groupId) {
    ref.read(selectedGroupIdProvider.notifier).state = groupId;
    ref.read(selectedEventIdProvider.notifier).state = null;
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(selectedEventProvider);
  }
  context.go('/groups/$groupId');
}

/// Participantes de um grupo: Integrantes e Temporários com as mesmas
/// funções de antes (convidar, perfil, remover...), editar grupo na barra
/// e seta de voltar pra lista. Se o grupo some (excluído, saiu dele),
/// volta pra lista.
class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final group = groupsAsync.valueOrNull
        ?.where((item) => item.id == groupId)
        .firstOrNull;
    final isAdmin =
        ref.watch(groupRoleProvider(groupId)).valueOrNull == 'ADMIN';

    if (groupsAsync.hasValue && group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/groups');
        }
      });
    }

    return AppScaffold(
      scrollsBehindTopBar: true,
      title: group?.name ?? 'Grupo',
      onBack: () => goBack(context, fallback: '/groups'),
      actions: [
        if (group != null && isAdmin)
          IconButton(
            tooltip: 'Editar grupo',
            onPressed: () => _showEditGroupDialog(context, ref, group),
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
      child: group == null
          ? groupsAsync.hasError
              ? ErrorState(
                  message: friendlyApiError(groupsAsync.error!,
                      fallback: 'Não foi possível carregar o grupo.'),
                  onRetry: () => ref.invalidate(groupsProvider),
                )
              : const Center(child: CircularProgressIndicator())
          // Busca de participantes fixa no topo; a lista rola por trás.
          : PinnedHeaderLayout(
              header: AppSearchField(
                hint: 'Buscar participante',
                onChanged: (value) =>
                    ref.read(groupMembersSearchProvider.notifier).state = value,
              ),
              builder: (context, top) => ListView(
                padding: EdgeInsets.fromLTRB(
                    16, top, 16, 16 + bottomBarInset(context)),
                children: [
                  // Eventos deste grupo (tela Eventos já filtrada nele). Mesma
                  // aparência do "Fechar evento": botão azul preenchido, à direita.
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () {
                        ref.read(selectedGroupIdProvider.notifier).state =
                            group.id;
                        ref.read(selectedEventIdProvider.notifier).state = null;
                        ref.invalidate(eventsProvider);
                        ref.invalidate(selectedEventProvider);
                        context.go('/events');
                      },
                      child: const Text('Ver eventos'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _GroupMembers(group: group),
                  _GroupTemporaryMembers(group: group),
                ],
              ),
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
      builder: (context, snapshot) => Consumer(builder: (context, ref, _) {
        final allMembers = snapshot.data ?? <GroupMemberModel>[];
        final query = ref.watch(groupMembersSearchProvider);
        // Temporários ficam só na lista "Temporários"; ao virar integrante
        // fixo a pessoa sobe pra cá.
        final members = allMembers
            .where((member) => !member.temporary)
            .where((member) => matchesSearchPtBr(member.nickname, query))
            .toList();
        // Convidar: admin e integrantes fixos (temporário não convida).
        final canInvite = isGroupAdmin ||
            allMembers.any((member) =>
                member.userId == currentUser?.id && !member.temporary);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Integrantes',
                        style: Theme.of(context).textTheme.titleMedium)),
                if (canInvite)
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
              EmptyState(
                icon: Icons.person_add_alt_outlined,
                // Mensagem da seção Integrantes, não da tela.
                centerOnScreen: false,
                message: query.isEmpty
                    ? 'Nenhum integrante cadastrado.'
                    : 'Nenhum integrante encontrado.',
              )
            else
              ...members.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      PersonAvatar(name: member.nickname, seed: member.userId),
                  title: Text(member.nickname),
                  subtitle: Text(member.roleLabel),
                  // Temporário: "Tornar integrante" no lugar do perfil.
                  // Pessoa sem cadastro: renomear e remover (só sem despesa).
                  trailing: isGroupAdmin && member.userId != currentUser?.id
                      ? Wrap(
                          children: [
                            if (member.placeholder)
                              IconButton(
                                tooltip: 'Editar nome',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  if (await _renamePlaceholder(
                                      context, ref, group.id, member)) {
                                    ref.invalidate(selectedGroupProvider);
                                  }
                                },
                              ),
                            // Perfil (inclui tornar temporário em fixo): só
                            // quem já criou conta.
                            if (!member.placeholder)
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
                              onPressed: () async {
                                if (member.placeholder) {
                                  if (await _removePlaceholder(
                                      context, ref, group.id, member)) {
                                    ref.invalidate(selectedGroupProvider);
                                  }
                                } else {
                                  await _confirmRemoveMember(
                                      context, ref, group, member);
                                }
                              },
                            ),
                          ],
                        )
                      : null,
                ),
              ),
          ],
        );
      }),
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
      content: Text(
          'Deseja sair de ${group.name}? Só é possível sair sem valores em aberto nos eventos que ainda não foram concluídos.'),
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

/// Perfil no grupo: Integrante/Admin e, para temporário com conta, também
/// "Temporário" — escolher Integrante ou Admin torna a pessoa fixa no grupo
/// (participa de todos os eventos). Retorna true se mudou algo.
Future<bool> _showEditMemberRoleDialog(BuildContext context, WidgetRef ref,
    GroupModel group, GroupMemberModel member) async {
  const temporaryRole = 'TEMPORARY';
  final initialRole = member.temporary ? temporaryRole : member.role;
  var role = initialRole;
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Perfil de ${member.nickname}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassDropdownField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Perfil no grupo'),
              items: [
                // Fixo também pode virar temporário (sai do grupo quando o
                // último evento com despesa dele for concluído).
                const DropdownMenuItem(
                    value: temporaryRole, child: Text('Temporário')),
                const DropdownMenuItem(
                    value: 'MEMBER', child: Text('Integrante (fixo)')),
                const DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
              ],
              onChanged: (value) => setState(() => role = value ?? role),
            ),
            if (!member.temporary && role == temporaryRole) ...[
              const SizedBox(height: 12),
              Text(
                '${member.nickname} passa a ser temporário(a): continua nos '
                'eventos em aberto e sai do grupo quando o último evento com '
                'despesa dele(a) for concluído.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (member.temporary && role != temporaryRole) ...[
              const SizedBox(height: 12),
              Text(
                '${member.nickname} deixa de ser temporário(a) e passa a '
                'participar de todos os eventos do grupo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
  if (saved != true || role == initialRole || !context.mounted) return false;
  try {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) throw Exception('Sessão expirada');
    final repository = ref.read(groupsRepositoryProvider);
    if (role == temporaryRole) {
      // Fixo → temporário (o backend recusa se for o último admin).
      await repository.makeTemporary(group.id, member.userId);
    } else if (member.temporary) {
      await repository.promoteTemporary(group.id, member.userId);
    }
    if (role == 'ADMIN' || (!member.temporary && role != temporaryRole)) {
      await repository.addMember(
        groupId: group.id,
        userId: member.userId,
        role: role,
      );
    }
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(groupRoleProvider(group.id));
    ref.invalidate(groupsProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
    if (role == temporaryRole && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.nickname} agora é temporário(a).')));
    } else if (member.temporary && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${member.nickname} agora é integrante do grupo.')));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível alterar o perfil.'))));
    }
    return false;
  }
}

/// Editar grupo: só o nome (a descrição saiu do app). "Excluir grupo" fica
/// aqui dentro, em vez de um botão solto ao lado do seletor de grupo.
Future<void> _showEditGroupDialog(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  final nameController = TextEditingController(text: group.name);
  final action = await showDialog<String>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Editar grupo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
              controller: nameController,
              maxLength: 50,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.of(context).pop('delete'),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir grupo'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Salvar')),
      ],
    ),
  );
  final name = nameController.text.trim();
  nameController.dispose();
  if (action == null || !context.mounted) {
    return;
  }
  if (action == 'delete') {
    await _deleteGroup(context, ref, group);
    return;
  }
  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um nome para o grupo.')));
    return;
  }
  try {
    await ref.read(groupsRepositoryProvider).update(
          groupId: group.id,
          name: name,
          // Mantém a descrição antiga, se houver: o campo só sumiu da tela.
          description: group.description,
        );
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível atualizar o grupo.'))));
    }
  }
}

Future<void> _showCreateGroupDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final saved = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Novo grupo'),
      content: TextField(
          controller: nameController,
          maxLength: 50,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome')),
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
  final name = nameController.text.trim();
  nameController.dispose();
  if (saved != true || !context.mounted) {
    return;
  }
  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um nome para o grupo.')));
    return;
  }
  try {
    final group = await ref.read(groupsRepositoryProvider).create(name: name);
    ref.read(selectedGroupIdProvider.notifier).state = group.id;
    ref.invalidate(groupsProvider);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
    // Grupo novo abre direto nos participantes (pra convidar).
    if (context.mounted) {
      context.go('/groups/${group.id}');
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível criar o grupo.'))));
    }
  }
}

Future<void> _showInviteDialog(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  final GroupInviteModel invite;
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
  // O link do grupo é fixo: sem "Gerar novo link", pra ninguém invalidar
  // sem querer um link já compartilhado.
  final url = '${Environment.webBaseUrl}/invite/${invite.id}';
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Convidar para o grupo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Envie este link para adicionar alguém ao grupo:'),
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

/// Admin-only: temporários do grupo ("Pessoas sem cadastro" e "Pessoas
/// temporárias" viraram uma lista só, 27/10/2026). Cadastrados pelo
/// "Incluir temporário" (só o nome), entram nas despesas de qualquer evento
/// e saem da lista quando todos os eventos com despesa deles fecham. Quem
/// entra pelo convite escolhendo o nome continua temporário até o admin
/// tornar integrante. Temporários antigos, presos a um evento, continuam
/// aparecendo aqui (esmaecidos quando o evento fecha).
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
    // Grupo recarregado (ex.: integrante alterado) também recarrega a lista.
    if (!identical(oldWidget.group, widget.group)) {
      _future = null;
    }
  }

  // Sem o evento do temporário (ex.: "· 10/2026"): só se tem conta.
  String _subtitle(GroupMemberModel member) =>
      member.placeholder ? 'Sem conta no app' : 'Com conta';

  @override
  Widget build(BuildContext context) {
    final isGroupAdmin =
        ref.watch(groupRoleProvider(widget.group.id)).valueOrNull == 'ADMIN';
    final query = ref.watch(groupMembersSearchProvider);
    // Todos os integrantes veem os temporários; só o admin altera.
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FutureBuilder<List<GroupMemberModel>>(
        future: _load(),
        builder: (context, snapshot) {
          final temporaries = [
            ...(snapshot.data ?? <GroupMemberModel>[])
                .where((member) => matchesSearchPtBr(member.nickname, query))
          ]..sort((first, second) => first.nickname
              .toLowerCase()
              .compareTo(second.nickname.toLowerCase()));
          // Quem não é admin só vê a seção se tiver algum temporário.
          if (!isGroupAdmin &&
              (snapshot.connectionState != ConnectionState.done ||
                  snapshot.hasError ||
                  temporaries.isEmpty)) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('Temporários',
                          style: Theme.of(context).textTheme.titleMedium)),
                  if (isGroupAdmin)
                    TextButton.icon(
                      onPressed: () async {
                        if (await showTemporaryGuestDialog(
                            context, ref, widget.group.id)) {
                          _reload();
                        }
                      },
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Incluir temporário'),
                    ),
                ],
              ),
              if (isGroupAdmin)
                Text(
                  'Cadastre só o nome para já lançar despesas. A pessoa sai da '
                  'lista quando todos os eventos com despesa dela forem '
                  'fechados. Depois que ela criar conta pelo convite, dá para '
                  'torná-la integrante do grupo.',
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
                    subtitle: Text(_subtitle(member)),
                    trailing: !isGroupAdmin
                        ? null
                        : Wrap(
                            children: [
                              // Só dá pra renomear quem ainda não tem conta: o
                              // nome de quem tem conta é dele.
                              if (member.placeholder)
                                IconButton(
                                  tooltip: 'Editar nome',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    if (await _renamePlaceholder(context, ref,
                                        widget.group.id, member)) {
                                      _reload();
                                    }
                                  },
                                ),
                              if (!member.placeholder)
                                IconButton(
                                  tooltip: 'Alterar perfil no grupo',
                                  icon: const Icon(
                                      Icons.manage_accounts_outlined),
                                  onPressed: () async {
                                    if (await _showEditMemberRoleDialog(
                                        context, ref, widget.group, member)) {
                                      _reload();
                                    }
                                  },
                                ),
                              if (member.placeholder)
                                IconButton(
                                  tooltip: 'Remover',
                                  icon:
                                      const Icon(Icons.person_remove_outlined),
                                  onPressed: () async {
                                    if (await _removePlaceholder(context, ref,
                                        widget.group.id, member)) {
                                      _reload();
                                    }
                                  },
                                ),
                            ],
                          ),
                  ),
                ),
              // Com algum temporário: link pra mandar o convite do grupo
              // (é por ele que o temporário cria conta e fica com as
              // despesas).
              if (isGroupAdmin &&
                  snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasError &&
                  temporaries.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () =>
                      _shareGroupInvite(context, ref, widget.group),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar convite do grupo'),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Abre o compartilhar do sistema com o link de convite do grupo.
Future<void> _shareGroupInvite(
    BuildContext context, WidgetRef ref, GroupModel group) async {
  final GroupInviteModel invite;
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
  final url = '${Environment.webBaseUrl}/invite/${invite.id}';
  await SharePlus.instance.share(
      ShareParams(text: 'Entre no grupo ${group.name} no DividiAí: $url'));
}

/// "Incluir temporário": o admin digita só o nome e a pessoa já entra no
/// grupo como temporária (sem conta) — dá pra lançar despesas dela em
/// qualquer evento aberto. Depois aparece o link do convite do grupo: quem
/// criar conta por ele e escolher o nome em "Quem é você?" fica com as
/// despesas e continua temporário. Retorna true se cadastrou.
Future<bool> showTemporaryGuestDialog(
    BuildContext context, WidgetRef ref, String groupId) async {
  final nameController = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Incluir temporário'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameController,
            maxLength: 40,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          Text(
            'Já entra com o nome, sem precisar de conta, e pode participar '
            'das despesas de qualquer evento aberto. Se criar conta pelo link '
            'do convite, fica com as despesas dele.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Adicionar')),
      ],
    ),
  );
  final nickname = nameController.text.trim();
  nameController.dispose();
  if (result != true || !context.mounted) {
    return false;
  }
  if (nickname.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da pessoa.')));
    return false;
  }
  try {
    await ref
        .read(groupsRepositoryProvider)
        .createPlaceholder(groupId, nickname: nickname, temporary: true);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(dashboardGroupBalancesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível adicionar a pessoa.'))));
    }
    return false;
  }
  if (!context.mounted) {
    return true;
  }
  final GroupInviteModel invite;
  try {
    invite = await ref.read(groupInviteRepositoryProvider).getOrCreate(groupId);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback:
                  '$nickname foi adicionado(a), mas não foi possível gerar o convite.'))));
    }
    return true;
  }
  if (!context.mounted) {
    return true;
  }
  final url = '${Environment.webBaseUrl}/invite/${invite.id}';
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$nickname adicionado(a)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mande este link se quiser que $nickname crie conta e '
              'acompanhe pelo app (opcional). No convite, é só escolher o '
              'próprio nome:'),
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
  return true;
}

Future<bool> _renamePlaceholder(BuildContext context, WidgetRef ref,
    String groupId, GroupMemberModel member) async {
  final controller = TextEditingController(text: member.nickname);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Renomear'),
      content: TextField(
        controller: controller,
        maxLength: 40,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nome'),
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
  final nickname = controller.text.trim();
  controller.dispose();
  if (confirmed != true || nickname.isEmpty || !context.mounted) {
    return false;
  }
  try {
    await ref
        .read(groupsRepositoryProvider)
        .renamePlaceholder(groupId, userId: member.userId, nickname: nickname);
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível renomear.'))));
    }
    return false;
  }
}

Future<bool> _removePlaceholder(BuildContext context, WidgetRef ref,
    String groupId, GroupMemberModel member) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remover nome'),
      content: Text('Remover ${member.nickname} do grupo? Só é possível '
          'enquanto não houver despesa lançada para essa pessoa.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }
  try {
    await ref
        .read(groupsRepositoryProvider)
        .deletePlaceholder(groupId, member.userId);
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              friendlyApiError(error, fallback: 'Não foi possível remover.'))));
    }
    return false;
  }
}
