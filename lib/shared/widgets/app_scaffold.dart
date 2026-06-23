import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/services/auth_repository.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.floatingActionButton,
  });

  final String title;
  final Widget child;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showUsers =
        ref.watch(currentUserProvider).valueOrNull?.admin ?? false;
    final routes = [
      '/',
      '/groups',
      '/events',
      '/expenses',
      '/reports',
      '/summary',
      if (showUsers) '/users',
      '/profile',
    ];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: NavigationDrawer(
        onDestinationSelected: (index) async {
          if (index == routes.length) {
            await ref.read(authRepositoryProvider).logout();
            ref.invalidate(currentUserProvider);
            if (context.mounted) {
              context.go('/login');
            }
            return;
          }

          context.go(routes[index]);
        },
        children: [
          const DrawerHeader(child: Text('DividiAi')),
          NavigationDrawerDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: Text('Dashboard'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: Text('Grupos'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: Text('Eventos'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: Text('Despesas'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: Text('Relatorios'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: Text('Extrato'),
          ),
          if (showUsers)
            const NavigationDrawerDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: Text('Usuarios'),
            ),
          NavigationDrawerDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Perfil'),
          ),
          Divider(),
          NavigationDrawerDestination(
            icon: Icon(Icons.logout_outlined),
            selectedIcon: Icon(Icons.logout),
            label: Text('Sair'),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: child),
    );
  }
}
