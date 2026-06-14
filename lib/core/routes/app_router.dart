import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/events/pages/events_page.dart';
import '../../features/expenses/pages/expenses_page.dart';
import '../../features/groups/pages/groups_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/reports/pages/reports_page.dart';
import '../../features/summary/pages/user_expense_summary_page.dart';
import '../../features/users/pages/users_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
          path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
      GoRoute(path: '/groups', builder: (context, state) => const GroupsPage()),
      GoRoute(path: '/events', builder: (context, state) => const EventsPage()),
      GoRoute(
          path: '/expenses', builder: (context, state) => const ExpensesPage()),
      GoRoute(
          path: '/reports', builder: (context, state) => const ReportsPage()),
      GoRoute(
          path: '/summary',
          builder: (context, state) => const UserExpenseSummaryPage()),
      GoRoute(path: '/users', builder: (context, state) => const UsersPage()),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfilePage()),
    ],
  );
});
