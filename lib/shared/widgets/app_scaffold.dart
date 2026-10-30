import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/auth/services/auth_repository.dart';
import '../../features/notifications/services/notifications_repository.dart';
import '../session_reset.dart';
import 'empty_state.dart';
import 'glass.dart';
import 'hide_fab_on_scroll.dart';
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
    this.actions,
    this.onBack,
    this.showBottomBar = true,
    this.titleFontSize,
  });

  final String title;
  // Tamanho do título (null = padrão, 22). Início usa 24.
  final double? titleFontSize;
  final Widget child;
  final Widget? floatingActionButton;
  // Seta de voltar à esquerda do título (telas abertas a partir de outra).
  final VoidCallback? onBack;
  // Ações extras no fim da AppBar, depois do sino de notificações e do
  // menu padrão — usado por telas que precisam de um botão próprio (ex.:
  // "Limpar notificações").
  final List<Widget>? actions;
  // false: sem a barra de menus no celular (ex.: Perfil, que tem seta de
  // voltar).
  final bool showBottomBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showUsers =
        ref.watch(currentUserProvider).valueOrNull?.admin ?? false;
    final isWide = MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;
    final currentPath = GoRouterState.of(context).uri.path;

    final scaffold = HideFabOnScroll(
      fab: floatingActionButton,
      body: child,
      builder: (fab, body, scrolledDown) => isWide
          ? _WideScaffold(
              title: title,
              titleFontSize: titleFontSize,
              showUsers: showUsers,
              currentPath: currentPath,
              floatingActionButton: fab,
              actions: actions,
              onBack: onBack,
              child: body,
            )
          : _NarrowScaffold(
              title: title,
              titleFontSize: titleFontSize,
              showUsers: showUsers,
              currentPath: currentPath,
              floatingActionButton: fab,
              actions: actions,
              onBack: onBack,
              showBottomBar: showBottomBar,
              compactBottomBar: scrolledDown,
              child: body,
            ),
    );
    // Com seta de voltar: arrastar da borda esquerda pra direita (iOS) e o
    // voltar do sistema (Android) fazem o mesmo que a seta.
    final back = onBack;
    return back == null ? scaffold : SwipeBack(onBack: back, child: scaffold);
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
    required this.titleFontSize,
    required this.showUsers,
    required this.currentPath,
    required this.floatingActionButton,
    required this.actions,
    required this.onBack,
    required this.child,
  });

  final String title;
  final double? titleFontSize;
  final bool showUsers;
  final String currentPath;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = [
      '/',
      '/groups',
      '/events',
      '/expenses',
      '/summary',
      if (showUsers) '/users',
      '/profile',
    ];
    // Participantes de um grupo (/groups/{id}) marcam Grupos.
    final selectedIndex = routes
        .indexOf(currentPath.startsWith('/groups/') ? '/groups' : currentPath);

    return Scaffold(
      appBar: glassAppBar(
        context,
        title: title,
        titleFontSize: titleFontSize,
        showDrawerButton: true,
        onBack: onBack,
        actions: [const _NotificationBell(), ...?actions],
      ),
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
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: Text('Extrato'),
          ),
          if (showUsers)
            const NavigationDrawerDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: Text('Usuários'),
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
      body: _ScreenBody(child: SafeArea(child: child)),
    );
  }
}

/// Layout para celular: barra inferior com os 4 destinos mais usados
/// (Início, Grupos, Eventos, Extrato; o Relatório saiu da barra e o saldo
/// fica em Despesas > Saldo). Nova despesa já tem seu
/// próprio botão (+) nas telas de Eventos/Despesas, então não duplicamos
/// aqui. O nome da pessoa logada aparece na AppBar e abre o Perfil ao
/// tocar; Sair e Usuários (admin) ficam no Perfil. Despesas abre tocando
/// num evento (Início/Eventos).
class _NarrowScaffold extends ConsumerWidget {
  const _NarrowScaffold({
    required this.title,
    required this.titleFontSize,
    required this.showUsers,
    required this.currentPath,
    required this.floatingActionButton,
    required this.actions,
    required this.onBack,
    required this.showBottomBar,
    required this.compactBottomBar,
    required this.child,
  });

  final String title;
  final double? titleFontSize;
  final bool showUsers;
  final String currentPath;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showBottomBar;
  final bool compactBottomBar;
  final Widget child;

  // Última aba da barra inferior que estava selecionada. Telas fora da
  // barra (Notificações, Perfil...) mantêm essa aba marcada em vez de
  // pular pra "Início" — senão o indicador da barra se mexia ao abrir o
  // sino.
  static int _lastIndex = 0;

  int _selectedIndex(String path) {
    if (path.startsWith('/groups/')) {
      path = '/groups';
    }
    final index = switch (path) {
      '/' => 0,
      '/groups' => 1,
      '/events' || '/expenses' => 2,
      '/summary' => 3,
      // Perfil e Extrato geral não são abas da barra: nenhuma fica marcada.
      '/profile' || '/summary/general' => -1,
      _ => null,
    };
    if (index == null) {
      return _lastIndex;
    }
    if (index >= 0) {
      _lastIndex = index;
    }
    return index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    return Scaffold(
      // Barra superior e menu inferior em "liquid glass" (padrão WhatsApp).
      appBar: glassAppBar(
        context,
        title: title,
        titleFontSize: titleFontSize,
        onBack: onBack,
        actions: [
          const _NotificationBell(),
          // Ações da tela (ex.: limpar notificações) logo depois do sino,
          // antes do nome de quem está logado.
          ...?actions,
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
        ],
      ),
      bottomNavigationBar: !showBottomBar
          ? null
          : GlassNavBar(
              compact: compactBottomBar,
              selectedIndex: _selectedIndex(currentPath),
              onSelected: (index) {
                const paths = ['/', '/groups', '/events', '/summary'];
                context.go(paths[index]);
              },
              items: const [
                GlassNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Início',
                ),
                GlassNavItem(
                  icon: Icons.groups_outlined,
                  selectedIcon: Icons.groups,
                  label: 'Grupos',
                ),
                GlassNavItem(
                  icon: Icons.event_outlined,
                  selectedIcon: Icons.event,
                  label: 'Eventos',
                ),
                GlassNavItem(
                  icon: Icons.list_alt_outlined,
                  selectedIcon: Icons.list_alt,
                  label: 'Extrato',
                ),
              ],
            ),
      // O conteúdo rola por trás da pílula do menu (vidro desfocado); as
      // listas somam bottomBarInset no fim pra o último item aparecer.
      extendBody: showBottomBar,
      floatingActionButton: floatingActionButton,
      body: _ScreenBody(child: SafeArea(bottom: false, child: child)),
    );
  }
}

/// Tela de onde o sino foi tocado: a seta de Notificações volta pra ela.
final notificationsReturnPathProvider = StateProvider<String>((ref) => '/');

/// Sino de notificações com badge de não lidas, usado nas duas variantes
/// de AppBar (larga e estreita). Sempre leva pra /notifications.
///
/// `notificationsProvider` é um FutureProvider comum: sem alguém chamar
/// invalidate, ele nunca recarrega sozinho — então o contador ficava preso
/// no valor do primeiro carregamento (geralmente 0) e um alerta de
/// cobrança recebido durante o uso do app nunca aparecia, só depois de
/// reiniciar. Como o AppScaffold (e esse sino) é recriado a cada troca de
/// tela, um refresh a cada vez que o sino "nasce" já cobre o uso normal;
/// o timer garante que também atualiza se a pessoa ficar parada na mesma
/// tela por um tempo.
class _NotificationBell extends ConsumerStatefulWidget {
  const _NotificationBell();

  @override
  ConsumerState<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<_NotificationBell> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  void _refresh() {
    if (mounted) {
      ref.invalidate(notificationsProvider);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    return IconButton(
      tooltip: 'Notificações',
      onPressed: () {
        // Notificações tem seta de voltar: guarda de onde veio.
        final from = GoRouterState.of(context).uri.toString();
        if (!from.startsWith('/notifications')) {
          ref.read(notificationsReturnPathProvider.notifier).state = from;
        }
        context.go('/notifications');
      },
      icon: Badge(
        label: Text('$unreadCount'),
        isLabelVisible: unreadCount > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
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

/// Corpo da tela: marca a área pra o [EmptyState] se centralizar nela.
class _ScreenBody extends StatefulWidget {
  const _ScreenBody({required this.child});

  final Widget child;

  @override
  State<_ScreenBody> createState() => _ScreenBodyState();
}

class _ScreenBodyState extends State<_ScreenBody> {
  final _bodyKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ScreenBodyScope(
      bodyKey: _bodyKey,
      child: KeyedSubtree(key: _bodyKey, child: widget.child),
    );
  }
}

/// Voltar arrastando: uma faixa fina na borda esquerda pega o arraste pra
/// direita (a tela acompanha o dedo) e chama [onBack] se passar de um
/// pedaço da tela ou for rápido. Só a borda, pra não brigar com listas e
/// itens que deslizam (ex.: apagar notificação). Também trata o voltar do
/// sistema (botão/gesto do Android): sem pilha de telas (as rotas usam
/// `go`), ele fecharia o app.
class SwipeBack extends StatefulWidget {
  const SwipeBack({super.key, required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  State<SwipeBack> createState() => _SwipeBackState();
}

class _SwipeBackState extends State<SwipeBack> {
  static const double _edgeWidth = 24;
  double _dragX = 0;

  void _onDragEnd(DragEndDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    final velocity = details.primaryVelocity ?? 0;
    final shouldGoBack = _dragX > width * 0.3 || velocity > 500;
    setState(() => _dragX = 0);
    if (shouldGoBack) {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          widget.onBack();
        }
      },
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(_dragX, 0),
            child: widget.child,
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _edgeWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) => setState(() => _dragX =
                  (_dragX + details.delta.dx)
                      .clamp(0, MediaQuery.sizeOf(context).width)),
              onHorizontalDragEnd: _onDragEnd,
              onHorizontalDragCancel: () => setState(() => _dragX = 0),
            ),
          ),
        ],
      ),
    );
  }
}
