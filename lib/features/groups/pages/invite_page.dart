import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api_error.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../auth/services/auth_repository.dart';
import '../models/group_invite_preview_model.dart';
import '../services/group_invite_repository.dart';
import '../services/groups_repository.dart';

class InvitePage extends ConsumerWidget {
  const InvitePage({super.key, required this.inviteId});

  final String inviteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          // Rolável: a lista "Quem é você?" pode ter muitos nomes.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: currentUserAsync.when(
              data: (user) => user == null
                  ? _SignInPrompt(inviteId: inviteId)
                  : _JoinGroup(inviteId: inviteId),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _SignInPrompt(inviteId: inviteId),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInPrompt extends ConsumerWidget {
  const _SignInPrompt({required this.inviteId});

  final String inviteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Você foi convidado para um grupo',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Entre ou crie uma conta para participar.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => _goTo(context, ref, '/login'),
          child: const Text('Entrar'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _goTo(context, ref, '/register'),
          child: const Text('Criar conta'),
        ),
      ],
    );
  }

  void _goTo(BuildContext context, WidgetRef ref, String route) {
    ref.read(pendingInviteIdProvider.notifier).state = inviteId;
    context.go(route);
  }
}

class _JoinGroup extends ConsumerStatefulWidget {
  const _JoinGroup({required this.inviteId});

  final String inviteId;

  @override
  ConsumerState<_JoinGroup> createState() => _JoinGroupState();
}

class _JoinGroupState extends ConsumerState<_JoinGroup> {
  late Future<GroupInvitePreviewModel> preview;
  bool joining = false;

  @override
  void initState() {
    super.initState();
    preview = ref.read(groupInviteRepositoryProvider).preview(widget.inviteId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GroupInvitePreviewModel>(
      future: preview,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Este link de convite não é mais válido.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Ir para o início'),
              ),
            ],
          );
        }
        final invite = snapshot.data!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Você foi convidado para o grupo',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(invite.groupName,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            if (invite.eventName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Participação temporária, só no evento "${invite.eventName}".',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            if (invite.placeholders.isEmpty)
              FilledButton(
                onPressed: joining ? null : () => _join(),
                child: joining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Entrar no grupo'),
              )
            else
              ..._whoAreYou(invite),
          ],
        );
      },
    );
  }

  /// "Quem é você?": nomes que o admin cadastrou antes (pessoas sem
  /// cadastro). Escolher um vincula as despesas dele à conta da pessoa;
  /// "Não estou na lista" entra como pessoa nova. Os dois pedem confirmação.
  List<Widget> _whoAreYou(GroupInvitePreviewModel invite) {
    return [
      Text('Quem é você?',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(
        'O administrador já cadastrou estes nomes no grupo. Escolha o seu '
        'para ficar com as despesas lançadas nele.',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      ...invite.placeholders.map(
        (option) => Card(
          child: ListTile(
            enabled: !joining,
            leading: PersonAvatar(name: option.nickname, seed: option.userId),
            title: Text(option.nickname),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmPlaceholder(option),
          ),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: joining ? null : _confirmNewPerson,
        child: joining
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Não estou na lista'),
      ),
    ];
  }

  Future<void> _confirmPlaceholder(InvitePlaceholderOption option) async {
    final confirmed = await _confirm(
      title: 'Você é ${option.nickname}?',
      message: 'As despesas lançadas para ${option.nickname} passam a ficar '
          'no seu cadastro. Confirme só se for você mesmo.',
    );
    if (confirmed) {
      await _join(placeholderUserId: option.userId);
    }
  }

  Future<void> _confirmNewPerson() async {
    final confirmed = await _confirm(
      title: 'Entrar como pessoa nova?',
      message: 'Você não selecionou nenhum dos nomes cadastrados pelo '
          'administrador. Vai entrar no grupo como uma pessoa nova, sem as '
          'despesas já lançadas para esses nomes.',
    );
    if (confirmed) {
      await _join();
    }
  }

  /// Só duas opções: Confirmar, ou Voltar pra lista de nomes.
  Future<bool> _confirm(
      {required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _join({String? placeholderUserId}) async {
    setState(() => joining = true);
    try {
      final member = await ref
          .read(groupInviteRepositoryProvider)
          .join(widget.inviteId, placeholderUserId: placeholderUserId);
      ref.read(selectedGroupIdProvider.notifier).state = member.groupId;
      ref.invalidate(groupsProvider);
      ref.invalidate(selectedGroupProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você entrou no grupo!')),
        );
        context.go('/groups');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível entrar no grupo.')),
          ),
        );
        // Ex.: outra pessoa escolheu o mesmo nome antes — recarrega a lista.
        if (placeholderUserId != null) {
          setState(() {
            preview = ref
                .read(groupInviteRepositoryProvider)
                .preview(widget.inviteId);
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => joining = false);
      }
    }
  }
}
