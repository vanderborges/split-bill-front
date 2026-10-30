import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../shared/api_error.dart';
import '../../../shared/session_reset.dart';
import '../../../shared/validators.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../auth/services/auth_repository.dart';
import '../../users/models/user_model.dart';
import '../../users/services/users_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return AppScaffold(
      scrollsBehindTopBar: true,
      title: 'Perfil',
      // Sem a barra de menus; a seta volta pro Início.
      showBottomBar: false,
      onBack: () => context.go('/'),
      child: userAsync.when(
        data: (user) {
          if (user == null) {
            return ErrorState(
              message: 'Sessão expirada. Entre novamente.',
              onRetry: () => ref.invalidate(currentUserProvider),
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg + topBarInset(context),
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom),
            children: [
              Row(
                children: [
                  PersonAvatar(name: user.nickname, seed: user.id, radius: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sem status/selo abaixo do nome (pedido do usuário).
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              ListTile(
                  title: const Text('Nome'), subtitle: Text(user.fullName)),
              ListTile(
                  title: const Text('Apelido'), subtitle: Text(user.nickname)),
              ListTile(title: const Text('E-mail'), subtitle: Text(user.email)),
              ListTile(
                  title: const Text('Telefone'), subtitle: Text(user.phone)),
              ListTile(
                  title: const Text('Chave PIX'), subtitle: Text(user.pixKey)),
              const SizedBox(height: AppSpacing.md),
              const _ThemeModeSelector(),
              const SizedBox(height: AppSpacing.lg),
              // Mesma aparência do "Alterar senha" (contorno).
              OutlinedButton.icon(
                onPressed: () => _showEditProfileDialog(context, ref, user),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar perfil'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _showChangePasswordDialog(context, ref),
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Alterar senha'),
              ),
              // No celular o menu "três pontos" da AppBar saiu: Usuários
              // (só admin) e Sair ficam aqui no perfil.
              if (user.admin && MediaQuery.sizeOf(context).width < 600) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.go('/users'),
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('Usuários'),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              // Só um link (vermelho, sem borda): ação rara e destrutiva,
              // não deve competir com os botões do Perfil.
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _showDeleteAccountDialog(context, ref, user),
                  child: const Text(
                    'Excluir conta',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _AppVersionText(),
            ],
          );
        },
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: 'Não foi possível carregar seu perfil.',
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }
}

/// Modo da tela: claro, escuro ou o padrão do sistema do aparelho.
class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text('Modo da tela',
              style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Seletor compacto (como antes), com os nomes Sistema | Dia | Noite;
        // Sistema com a engrenagem.
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_outlined),
                  label: Text('Sistema')),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Dia')),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Noite')),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                ref.read(themeModeProvider.notifier).set(selection.first),
          ),
        ),
      ],
    );
  }
}

/// Versão instalada do app (ex.: "Versão 1.0.0 (35)").
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});

class _AppVersionText extends ConsumerWidget {
  const _AppVersionText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).valueOrNull;
    if (version == null) {
      return const SizedBox.shrink();
    }
    return Text(
      'Versão $version',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

Future<void> _logout(BuildContext context, WidgetRef ref) async {
  await ref.read(authRepositoryProvider).logout(keepBiometric: true);
  resetSessionScopedProviders(ref);
  if (context.mounted) {
    context.go('/login');
  }
}

Future<void> _showChangePasswordDialog(
    BuildContext context, WidgetRef ref) async {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmationController = TextEditingController();
  final saved = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Alterar senha'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: currentPasswordController,
              maxLength: 64,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha atual')),
          const SizedBox(height: 12),
          TextField(
              controller: newPasswordController,
              maxLength: 64,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova senha')),
          const SizedBox(height: 12),
          TextField(
              controller: confirmationController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirmar nova senha')),
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
    _disposeControllers([
      currentPasswordController,
      newPasswordController,
      confirmationController
    ]);
    return;
  }
  if (newPasswordController.text.length < 6 ||
      newPasswordController.text != confirmationController.text) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'A nova senha deve ter ao menos 6 caracteres e ser confirmada.')));
    _disposeControllers([
      currentPasswordController,
      newPasswordController,
      confirmationController
    ]);
    return;
  }
  try {
    await ref.read(usersRepositoryProvider).changePassword(
          currentPassword: currentPasswordController.text,
          newPassword: newPasswordController.text,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha alterada com sucesso.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível alterar a senha.'))));
    }
  } finally {
    _disposeControllers([
      currentPasswordController,
      newPasswordController,
      confirmationController
    ]);
  }
}

Future<void> _showEditProfileDialog(
    BuildContext context, WidgetRef ref, UserModel user) async {
  final fullNameController = TextEditingController(text: user.fullName);
  final nicknameController = TextEditingController(text: user.nickname);
  final emailController = TextEditingController(text: user.email);
  final phoneController = TextEditingController(text: user.phone);
  final pixKeyController = TextEditingController(text: user.pixKey);

  final saved = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Editar perfil'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: fullNameController,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Nome completo')),
              const SizedBox(height: 12),
              TextField(
                  controller: nicknameController,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Apelido')),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                maxLength: 120,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                maxLength: 20,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: pixKeyController,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Chave PIX')),
            ],
          ),
        ),
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
    _disposeControllers([
      fullNameController,
      nicknameController,
      emailController,
      phoneController,
      pixKeyController
    ]);
    return;
  }

  final values = [
    fullNameController.text.trim(),
    nicknameController.text.trim(),
    emailController.text.trim(),
    phoneController.text.trim(),
    pixKeyController.text.trim(),
  ];
  if (values.any((value) => value.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos.')));
    _disposeControllers([
      fullNameController,
      nicknameController,
      emailController,
      phoneController,
      pixKeyController
    ]);
    return;
  }

  if (!isValidEmail(values[2])) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um e-mail válido.')));
    _disposeControllers([
      fullNameController,
      nicknameController,
      emailController,
      phoneController,
      pixKeyController
    ]);
    return;
  }

  try {
    await ref.read(usersRepositoryProvider).update(
          id: user.id,
          fullName: values[0],
          nickname: values[1],
          email: values[2],
          phone: values[3],
          pixKey: values[4],
          billingUserId: user.billingUserId,
          admin: user.admin,
          active: user.active,
        );
    ref.invalidate(currentUserProvider);
    ref.invalidate(usersProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível atualizar o perfil.'))));
    }
  } finally {
    _disposeControllers([
      fullNameController,
      nicknameController,
      emailController,
      phoneController,
      pixKeyController
    ]);
  }
}

void _disposeControllers(List<TextEditingController> controllers) {
  for (final controller in controllers) {
    controller.dispose();
  }
}

Future<void> _showDeleteAccountDialog(
    BuildContext context, WidgetRef ref, UserModel user) async {
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Excluir conta'),
      // Sem digitar "EXCLUIR": o aviso + o botão vermelho já confirmam.
      content: const Text(
        'Esta ação é permanente. Sua conta, seus dados de perfil e seu '
        'acesso ao DividiAí serão excluídos e não podem ser recuperados. '
        'Despesas e grupos compartilhados com outras pessoas podem '
        'continuar visíveis para elas.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Excluir definitivamente'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return;
  }

  try {
    await ref.read(usersRepositoryProvider).delete(user.id);
    await ref.read(authRepositoryProvider).logout();
    resetSessionScopedProviders(ref);
    if (context.mounted) {
      context.go('/login');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sua conta foi excluída.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyApiError(error,
              fallback: 'Não foi possível excluir sua conta.')),
        ),
      );
    }
  }
}
