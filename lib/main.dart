import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_router.dart';
import 'core/routes/url_strategy.dart';
import 'core/theme/app_theme.dart';

void main() {
  configureUrlStrategy();
  runApp(const ProviderScope(child: DividiAiApp()));
}

class DividiAiApp extends ConsumerWidget {
  const DividiAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'DividiAi',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
