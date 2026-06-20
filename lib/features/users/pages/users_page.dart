import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/services/auth_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../models/user_model.dart';
import '../services/users_repository.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = currentUser?.admin ?? false;

    return AppScaffold(
      title: 'Usuarios',
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showUserDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      child: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
                child: Text(isAdmin
                    ? 'Nenhum usuario cadastrado.'
                    : 'Nenhum usuario disponivel.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.fullName),
                onTap: () => _showUserDetailsDialog(context, user),
                trailing: isAdmin
                    ? Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Editar usuario',
                            onPressed: () =>
                                _showUserDialog(context, ref, user),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Apagar usuario',
                            onPressed: () => _confirmDeleteUser(
                                context, ref, user.id, user.fullName),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar usuarios: $error')),
      ),
    );
  }
}

Future<void> _showUserDetailsDialog(BuildContext context, UserModel user) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(user.fullName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apelido: ${user.nickname}'),
          Text('Email: ${user.email}'),
          Text('Telefone: ${user.phone}'),
          Text('Chave PIX: ${user.pixKey}'),
          Text('Perfil: ${user.admin ? 'Administrador' : 'Usuario'}'),
          Text('Status: ${user.active ? 'Ativo' : 'Inativo'}'),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar')),
      ],
    ),
  );
}

Future<void> _showUserDialog(BuildContext context, WidgetRef ref,
    [UserModel? user]) async {
  final fullNameController = TextEditingController(text: user?.fullName ?? '');
  final nicknameController = TextEditingController(text: user?.nickname ?? '');
  final emailController = TextEditingController(text: user?.email ?? '');
  final phoneController = TextEditingController(text: user?.phone ?? '');
  final pixKeyController = TextEditingController(text: user?.pixKey ?? '');
  final passwordController = TextEditingController();
  bool admin = user?.admin ?? false;
  bool active = user?.active ?? true;

  final saved = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(user == null ? 'Cadastrar usuario' : 'Editar usuario'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fullNameController,
                      decoration:
                          const InputDecoration(labelText: 'Nome completo'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nicknameController,
                      decoration: const InputDecoration(labelText: 'Apelido'),
                    ),
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
                      decoration: const InputDecoration(labelText: 'Chave PIX'),
                    ),
                    if (user == null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Senha'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: admin,
                      title: const Text('Administrador'),
                      onChanged: (value) => setState(() => admin = value),
                    ),
                    SwitchListTile(
                      value: active,
                      title: const Text('Ativo'),
                      onChanged: (value) => setState(() => active = value),
                    ),
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
          );
        },
      );
    },
  );

  if (saved != true) {
    _disposeControllers([
      fullNameController,
      nicknameController,
      emailController,
      phoneController,
      pixKeyController,
      passwordController,
    ]);
    return;
  }

  if (!context.mounted) {
    _disposeControllers([
      fullNameController,
      nicknameController,
      emailController,
      phoneController,
      pixKeyController,
      passwordController,
    ]);
    return;
  }

  final fullName = fullNameController.text.trim();
  final nickname = nicknameController.text.trim();
  final email = emailController.text.trim();
  final phone = phoneController.text.trim();
  final pixKey = pixKeyController.text.trim();
  final password = passwordController.text;

  if ([fullName, nickname, email, phone, pixKey]
          .any((value) => value.isEmpty) ||
      (user == null && password.length < 6)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Preencha todos os campos. Senha deve ter ao menos 6 caracteres.')),
    );
    _disposeControllers([
      fullNameController,
      nicknameController,
      emailController,
      phoneController,
      pixKeyController,
      passwordController,
    ]);
    return;
  }

  try {
    if (user == null) {
      await ref.read(usersRepositoryProvider).create(
            fullName: fullName,
            nickname: nickname,
            email: email,
            phone: phone,
            pixKey: pixKey,
            password: password,
            admin: admin,
          );
    } else {
      await ref.read(usersRepositoryProvider).update(
            id: user.id,
            fullName: fullName,
            nickname: nickname,
            email: email,
            phone: phone,
            pixKey: pixKey,
            admin: admin,
            active: active,
          );
    }
    ref.invalidate(usersProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel salvar usuario: $error')),
      );
    }
  } finally {
    _disposeControllers([
      fullNameController,
      nicknameController,
      emailController,
      phoneController,
      pixKeyController,
      passwordController,
    ]);
  }
}

Future<void> _confirmDeleteUser(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String fullName,
) async {
  final confirmed = await showDialog<bool>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Apagar usuario'),
        content: Text('Deseja apagar $fullName?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apagar')),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    await ref.read(usersRepositoryProvider).delete(userId);
    ref.invalidate(usersProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel apagar usuario: $error')),
      );
    }
  }
}

void _disposeControllers(List<TextEditingController> controllers) {
  for (final controller in controllers) {
    controller.dispose();
  }
}
