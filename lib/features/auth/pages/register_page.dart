import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../users/services/users_repository.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final nicknameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final pixKeyController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    fullNameController.dispose();
    nicknameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    pixKeyController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Criar conta',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Depois do cadastro, um admin pode adicionar voce aos grupos.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: fullNameController,
                    textInputAction: TextInputAction.next,
                    decoration:
                        const InputDecoration(labelText: 'Nome completo'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nicknameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Apelido'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: _email,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pixKeyController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Chave PIX'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    validator: _password,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration:
                        const InputDecoration(labelText: 'Confirmar senha'),
                    validator: (value) =>
                        _confirmPassword(value, passwordController.text),
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving ? null : _save,
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cadastrar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: saving ? null : () => context.go('/login'),
                    child: const Text('Voltar para entrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (saving || formKey.currentState?.validate() != true) {
      return;
    }
    setState(() => saving = true);
    try {
      await ref.read(usersRepositoryProvider).create(
            fullName: fullNameController.text.trim(),
            nickname: nicknameController.text.trim(),
            email: emailController.text.trim(),
            phone: phoneController.text.trim(),
            pixKey: pixKeyController.text.trim(),
            password: passwordController.text,
            admin: false,
          );
      ref.invalidate(usersProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Cadastro criado. Aguarde um admin adicionar voce ao grupo.')),
      );
      context.go('/login');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Nao foi possivel cadastrar: ${_errorMessage(error)}')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Campo obrigatorio';
  }
  return null;
}

String? _email(String? value) {
  final requiredMessage = _required(value);
  if (requiredMessage != null) {
    return requiredMessage;
  }
  if (!value!.contains('@')) {
    return 'Email invalido';
  }
  return null;
}

String? _password(String? value) {
  final requiredMessage = _required(value);
  if (requiredMessage != null) {
    return requiredMessage;
  }
  if (value!.length < 6) {
    return 'Use ao menos 6 caracteres';
  }
  return null;
}

String? _confirmPassword(String? value, String password) {
  final requiredMessage = _required(value);
  if (requiredMessage != null) {
    return requiredMessage;
  }
  if (value != password) {
    return 'As senhas nao conferem';
  }
  return null;
}

String _errorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (error.message != null) {
      return error.message!;
    }
  }
  return error.toString();
}
