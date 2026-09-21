import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api_error.dart';
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
          child: Padding(
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
        Text('Voce foi convidado para um grupo',
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
  late final Future<GroupInvitePreviewModel> preview;
  bool joining = false;

  @override
  void initState() {
    super.initState();
    preview =
        ref.read(groupInviteRepositoryProvider).preview(widget.inviteId);
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
              const Text('Este link de convite nao e mais valido.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Ir para o inicio'),
              ),
            ],
          );
        }
        final invite = snapshot.data!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Voce foi convidado para o grupo',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(invite.groupName,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: joining ? null : _join,
              child: joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrar no grupo'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _join() async {
    setState(() => joining = true);
    try {
      final member =
          await ref.read(groupInviteRepositoryProvider).join(widget.inviteId);
      ref.read(selectedGroupIdProvider.notifier).state = member.groupId;
      ref.invalidate(groupsProvider);
      ref.invalidate(selectedGroupProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voce entrou no grupo!')),
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
      }
    } finally {
      if (mounted) {
        setState(() => joining = false);
      }
    }
  }
}
