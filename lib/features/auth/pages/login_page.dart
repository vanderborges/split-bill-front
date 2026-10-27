import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/session_reset.dart';
import '../../../shared/widgets/splash_video.dart';
import '../../groups/services/group_invite_repository.dart';
import '../../notifications/services/push_service.dart';
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
  bool rememberMe = true;
  bool autoLoggingIn = true;

  /// Abertura com vídeo: completa quando o vídeo acaba ou é pulado. Só
  /// toca na primeira vez que o app abre — voltar pro login (ex.: Sair)
  /// não repete o vídeo.
  final _splashDone = Completer<void>();
  static bool _splashPlayed = false;
  Future<bool>? biometricAvailable;

  @override
  void initState() {
    super.initState();
    if (_splashPlayed) {
      _splashDone.complete();
    }
    biometricAvailable = _canSignInWithBiometrics();
    _tryAutoLogin();
  }

  /// "Manter conectado": se a última sessão pediu pra lembrar e ainda há
  /// token salvo, valida o token no backend e entra direto. Token
  /// recusado pelo backend (expirado/inválido) é descartado; falha de rede
  /// (ex.: Render acordando) só cai na tela de login, mantendo o token.
  Future<void> _tryAutoLogin() async {
    final auth = ref.read(authRepositoryProvider);
    try {
      final remember = await auth.rememberMe();
      if (mounted) {
        setState(() => rememberMe = remember);
      }
      final token = await auth.token();
      if (!remember || token == null || token.isEmpty) {
        return;
      }
      try {
        await auth.me();
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if (status != null && status < 500) {
          await auth.logout();
          if (mounted) {
            setState(() => biometricAvailable = _canSignInWithBiometrics());
          }
        }
        return;
      }
      final pendingInviteId = ref.read(pendingInviteIdProvider);
      resetSessionScopedProviders(ref);
      // Só sai da abertura depois do vídeo (ou de a pessoa pular).
      await _splashDone.future;
      if (mounted) {
        context.go(_afterLoginRoute(pendingInviteId));
      }
    } catch (_) {
      // Qualquer outra falha: segue pro login manual.
    } finally {
      await _splashDone.future;
      if (mounted) {
        setState(() => autoLoggingIn = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (autoLoggingIn && !_splashDone.isCompleted) {
      return Scaffold(
        body: SplashVideo(onFinished: () {
          _splashPlayed = true;
          if (!_splashDone.isCompleted) {
            _splashDone.complete();
            // Login ainda validando (ex.: servidor acordando): cai no
            // "carregando" abaixo.
            if (mounted) {
              setState(() {});
            }
          }
        }),
      );
    }
    if (autoLoggingIn) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DividiAí',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }
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
                Text('DividiAí',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
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
                CheckboxListTile(
                  value: rememberMe,
                  onChanged: (value) =>
                      setState(() => rememberMe = value ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Manter conectado'),
                ),
                const SizedBox(height: 8),
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
        const SnackBar(content: Text('Informe e-mail e senha.')),
      );
      return;
    }

    final pendingInviteId = ref.read(pendingInviteIdProvider);
    setState(() => loading = true);
    try {
      await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
            rememberMe: rememberMe,
          );
      resetSessionScopedProviders(ref);
      if (mounted) {
        setState(() {
          biometricAvailable = _canSignInWithBiometrics();
        });
        context.go(_afterLoginRoute(pendingInviteId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail ou senha inválidos.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _biometricLogin() async {
    final pendingInviteId = ref.read(pendingInviteIdProvider);
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
        resetSessionScopedProviders(ref);
        if (mounted) {
          setState(() {
            biometricAvailable = _canSignInWithBiometrics();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sessão expirada. Entre com e-mail e senha.'),
            ),
          );
        }
        return;
      }
      resetSessionScopedProviders(ref);
      if (mounted) {
        context.go(_afterLoginRoute(pendingInviteId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível autenticar com biometria.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => biometricLoading = false);
      }
    }
  }

  /// Pra onde ir depois do login. Com convite pendente, volta pra tela do
  /// convite (agora logado) em vez de entrar no grupo direto: lá a pessoa
  /// escolhe "Quem é você?" entre os nomes pré-cadastrados pelo admin, ou
  /// entra como pessoa nova — e convite expirado mostra o aviso lá mesmo.
  /// [pendingInviteId] must be captured before calling
  /// [resetSessionScopedProviders], which clears it.
  String _afterLoginRoute(String? pendingInviteId) {
    if (pendingInviteId != null) {
      return '/invite/$pendingInviteId';
    }
    // App aberto tocando numa notificação de push.
    final pushRoute = ref.read(pendingPushRouteProvider);
    if (pushRoute != null) {
      ref.read(pendingPushRouteProvider.notifier).state = null;
      return pushRoute;
    }
    return '/';
  }
}
