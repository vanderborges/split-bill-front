import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/services/auth_repository.dart';
import '../features/dashboard/services/dashboard_repository.dart';
import '../features/events/services/events_repository.dart';
import '../features/expenses/services/expenses_repository.dart';
import '../features/groups/services/group_invite_repository.dart';
import '../features/groups/services/groups_repository.dart';
import '../features/months/services/months_repository.dart';
import '../features/reports/services/reports_repository.dart';
import '../features/settlements/services/event_settlements_repository.dart';
import '../features/users/services/users_repository.dart';

/// Clears every provider that caches data scoped to the signed-in user.
///
/// Riverpod normally re-derives a `FutureProvider` when a provider it
/// `watch`es (like [currentUserProvider]) changes, but switching accounts
/// in the same tab/app session (logout, or logging in as someone else
/// without a full reload) was leaving stale data from the previous user
/// on screen. Call this on both logout and successful login so a fresh
/// identity always starts from a clean slate.
void resetSessionScopedProviders(WidgetRef ref) {
  ref.invalidate(currentUserProvider);
  ref.invalidate(groupsProvider);
  ref.invalidate(selectedGroupIdProvider);
  ref.invalidate(selectedGroupProvider);
  ref.invalidate(pendingInviteIdProvider);
  ref.invalidate(dashboardGroupBalancesProvider);
  ref.invalidate(eventsProvider);
  ref.invalidate(openEventsProvider);
  ref.invalidate(selectedEventIdProvider);
  ref.invalidate(selectedEventProvider);
  ref.invalidate(currentMonthExpensesProvider);
  ref.invalidate(selectedEventExpensesProvider);
  ref.invalidate(monthsProvider);
  ref.invalidate(currentMonthProvider);
  ref.invalidate(currentMonthReportProvider);
  ref.invalidate(selectedEventReportProvider);
  ref.invalidate(selectedEventSettlementsProvider);
  ref.invalidate(usersProvider);
}
