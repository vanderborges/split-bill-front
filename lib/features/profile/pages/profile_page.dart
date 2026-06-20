import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/services/auth_repository.dart';
import '../../users/models/user_model.dart';
import '../../users/services/users_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return AppScaffold(
      title: 'Perfil',
      child: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
                child: Text('Sessao expirada. Entre novamente.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                  title: const Text('Nome'), subtitle: Text(user.fullName)),
              ListTile(
                  title: const Text('Apelido'), subtitle: Text(user.nickname)),
              ListTile(title: const Text('Email'), subtitle: Text(user.email)),
              ListTile(
                  title: const Text('Telefone'), subtitle: Text(user.phone)),
              ListTile(
                  title: const Text('Chave PIX'), subtitle: Text(user.pixKey)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _showEditProfileDialog(context, ref, user),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar perfil'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar perfil: $error')),
      ),
    );
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
                  decoration:
                      const InputDecoration(labelText: 'Nome completo')),
              const SizedBox(height: 12),
              TextField(
                  controller: nicknameController,
                  decoration: const InputDecoration(labelText: 'Apelido')),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: pixKeyController,
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

  try {
    await ref.read(usersRepositoryProvider).update(
          id: user.id,
          fullName: values[0],
          nickname: values[1],
          email: values[2],
          phone: values[3],
          pixKey: values[4],
          admin: user.admin,
          active: user.active,
        );
    ref.invalidate(currentUserProvider);
    ref.invalidate(usersProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nao foi possivel atualizar perfil: $error')));
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
