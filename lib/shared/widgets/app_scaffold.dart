import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/auth/services/auth_repository.dart';
import '../../features/expenses/services/new_expense_intent.dart';
import '../session_reset.dart';
import 'person_avatar.dart';

/// Abaixo desta largura a navegação principal vira uma barra inferior
/// (celular); a partir daqui mantém o Drawer lateral (tablet/web), que já
/// funciona bem nesse formato — ver Etapa 5 de docs/ux-roadmap-dividiai.md.
const double _wideLayoutBreakpoint = 600;

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
    final isWide = MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;
    final currentPath = GoRouterState.of(context).uri.path;

    if (isWide) {
      return _WideScaffold(
        title: title,
        showUsers: showUsers,
        currentPath: currentPath,
        floatingActionButton: floatingActionButton,
        child: child,
      );
    }

    return _NarrowScaffold(
      title: title,
      showUsers: showUsers,
      currentPath: currentPath,
      floatingActionButton: floatingActionButton,
      child: child,
    );
  }
}

Future<void> _logout(BuildContext context, WidgetRef ref) async {
  await ref.read(authRepositoryProvider).logout();
  resetSessionScopedProviders(ref);
  if (context.mounted) {
    context.go('/login');
  }
}

/// Layout para tablet/web: Drawer lateral com todos os destinos — o
/// comportamento original da tela, preservado sem mudanças estruturais.
class _WideScaffold extends ConsumerWidget {
  const _WideScaffold({
    required this.title,
    required this.showUsers,
    required this.currentPath,
    required this.floatingActionButton,
    required this.child,
  });

  final String title;
  final bool showUsers;
  final String currentPath;
  final Widget? floatingActionButton;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final selectedIndex = routes.indexOf(currentPath);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: NavigationDrawer(
        selectedIndex: selectedIndex < 0 ? null : selectedIndex,
        onDestinationSelected: (index) async {
          if (index == routes.length) {
            await _logout(context, ref);
            return;
          }
          context.go(routes[index]);
        },
        children: [
          const _DrawerBrandHeader(),
          NavigationDrawerDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: Text('Início'),
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

/// Layout para celular: barra inferior com os 5 destinos mais usados
/// (Início, Eventos, [+] Nova despesa, Extrato, Relatório). O nome da
/// pessoa logada aparece na AppBar e abre o Perfil ao tocar; Grupos,
/// Despesas e Usuários (admin) ficam a um toque de distância no menu
/// "Mais" — nenhuma rota deixou de existir, só mudou de onde é alcançada.
class _NarrowScaffold extends ConsumerWidget {
  const _NarrowScaffold({
    required this.title,
    required this.showUsers,
    required this.currentPath,
    required this.floatingActionButton,
    required this.child,
  });

  final String title;
  final bool showUsers;
  final String currentPath;
  final Widget? floatingActionButton;
  final Widget child;

  static const _quickAddIndex = 2;

  int _selectedIndex(String path) {
    switch (path) {
      case '/':
        return 0;
      case '/events':
      case '/expenses':
        return 1;
      case '/summary':
        return 3;
      case '/reports':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (currentUser != null)
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.go('/profile'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PersonAvatar(
                      name: currentUser.nickname,
                      seed: currentUser.id,
                      radius: 14,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 84),
                      child: Text(
                        currentUser.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _logout(context, ref);
                return;
              }
              context.go(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '/groups', child: Text('Grupos')),
              const PopupMenuItem(
                  value: '/expenses', child: Text('Despesas')),
              if (showUsers)
                const PopupMenuItem(
                    value: '/users', child: Text('Usuários')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Sair')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(currentPath),
        onDestinationSelected: (index) {
          if (index == _quickAddIndex) {
            ref.read(pendingAutoOpenExpenseProvider.notifier).state = true;
            context.go('/expenses');
            return;
          }
          const paths = ['/', '/events', '', '/summary', '/reports'];
          context.go(paths[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Eventos',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Nova',
            tooltip: 'Nova despesa',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Extrato',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Relatório',
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: child),
    );
  }
}

class _DrawerBrandHeader extends StatelessWidget {
  const _DrawerBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.md),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'DividiAí',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
