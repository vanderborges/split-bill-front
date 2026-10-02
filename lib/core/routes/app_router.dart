import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/events/pages/events_page.dart';
import '../../features/expenses/pages/expenses_page.dart';
import '../../features/groups/pages/groups_page.dart';
import '../../features/groups/pages/invite_page.dart';
import '../../features/notifications/pages/notifications_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/reports/pages/reports_page.dart';
import '../../features/summary/pages/user_expense_summary_page.dart';
import '../../features/users/pages/users_page.dart';

/// Troca de tela sem animação de slide/fade — usada nas rotas de primeiro
/// nível (as mesmas que aparecem na barra de navegação inferior no
/// celular). Cada uma delas monta seu próprio `AppScaffold`/`NavigationBar`
/// do zero (não há um shell persistente), então a transição padrão do
/// GoRouter fazia a tela inteira — barra incluída — deslizar/desaparecer a
/// cada toque. Sem transição, a barra fica parada no lugar e só o
/// conteúdo e o item selecionado mudam.
CustomTransitionPage<void> _noTransitionPage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
          path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              _noTransitionPage(const DashboardPage())),
      GoRoute(
          path: '/groups',
          pageBuilder: (context, state) =>
              _noTransitionPage(const GroupsPage())),
      GoRoute(
          path: '/invite/:inviteId',
          builder: (context, state) => InvitePage(
              inviteId: state.pathParameters['inviteId']!)),
      GoRoute(
          path: '/events',
          pageBuilder: (context, state) =>
              _noTransitionPage(const EventsPage())),
      GoRoute(
          path: '/expenses',
          pageBuilder: (context, state) =>
              _noTransitionPage(const ExpensesPage())),
      GoRoute(
          path: '/reports',
          pageBuilder: (context, state) =>
              _noTransitionPage(const ReportsPage())),
      GoRoute(
          path: '/summary',
          pageBuilder: (context, state) =>
              _noTransitionPage(const UserExpenseSummaryPage())),
      GoRoute(path: '/users', builder: (context, state) => const UsersPage()),
      GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsPage()),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfilePage()),
    ],
  );
});
