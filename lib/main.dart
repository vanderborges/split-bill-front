import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_router.dart';
import 'core/routes/url_strategy.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/services/auth_repository.dart';
import 'features/notifications/services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  await initializePush();
  final container = ProviderContainer();
  // App aberto por um toque na notificação: guarda pra onde ir antes da
  // tela de login decidir a rota.
  await container.read(pushServiceProvider).handleInitialMessage();
  runApp(UncontrolledProviderScope(
      container: container, child: const DividiAiApp()));
}

class DividiAiApp extends ConsumerWidget {
  const DividiAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Entrou alguém (login, "Manter conectado" ou troca de conta):
    // registra este aparelho pra receber push dessa conta.
    ref.listen(currentUserProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null && previous?.valueOrNull?.id != user.id) {
        ref.read(pushServiceProvider).registerDevice();
      }
    });

    return MaterialApp.router(
      title: 'DividiAí',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
