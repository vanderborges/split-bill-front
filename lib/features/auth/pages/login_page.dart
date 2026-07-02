import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_repository.dart';
import '../services/biometric_auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool biometricLoading = false;
  bool showPassword = false;
  Future<bool>? biometricAvailable;

  @override
  void initState() {
    super.initState();
    biometricAvailable = _canSignInWithBiometrics();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('DividiAi',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    suffixIcon: IconButton(
                      tooltip: showPassword ? 'Ocultar senha' : 'Mostrar senha',
                      icon: Icon(
                        showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => showPassword = !showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: loading ? null : _login,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
                FutureBuilder<bool>(
                  future: biometricAvailable,
                  builder: (context, snapshot) {
                    if (snapshot.data != true) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: loading || biometricLoading
                            ? null
                            : _biometricLogin,
                        icon: biometricLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.fingerprint),
                        label: const Text('Entrar com biometria'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Cadastre-se'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _canSignInWithBiometrics() {
    return ref.read(biometricAuthServiceProvider).canSignInWithBiometrics();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe email e senha.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      ref.invalidate(currentUserProvider);
      if (mounted) {
        setState(() {
          biometricAvailable = _canSignInWithBiometrics();
        });
        context.go('/');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email ou senha invalidos.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _biometricLogin() async {
    setState(() => biometricLoading = true);
    try {
      final authenticated =
          await ref.read(biometricAuthServiceProvider).authenticate();
      if (!authenticated) {
        return;
      }
      try {
        await ref.read(authRepositoryProvider).me();
      } catch (_) {
        await ref.read(authRepositoryProvider).logout();
        if (mounted) {
          setState(() {
            biometricAvailable = _canSignInWithBiometrics();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sessao expirada. Entre com email e senha.'),
            ),
          );
        }
        return;
      }
      ref.invalidate(currentUserProvider);
      if (mounted) {
        context.go('/');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel autenticar com biometria.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => biometricLoading = false);
      }
    }
  }
}
