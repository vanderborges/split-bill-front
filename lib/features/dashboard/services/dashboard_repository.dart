import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../auth/services/auth_repository.dart';
import '../../events/services/events_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../../reports/services/reports_repository.dart';
import '../models/dashboard_group_balance_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dioProvider));
});

final dashboardGroupBalancesProvider =
    FutureProvider<List<DashboardGroupBalanceModel>>((ref) async {
  try {
    return await ref.watch(dashboardRepositoryProvider).getGroupBalances();
  } catch (_) {
    return _fallbackGroupBalances(ref);
  }
});

class DashboardRepository {
  const DashboardRepository(this.dio);

  final Dio dio;

  Future<List<DashboardGroupBalanceModel>> getGroupBalances() async {
    final response = await dio.get<List<dynamic>>('/dashboard/group-balances');
    return response.data!
        .map((item) =>
            DashboardGroupBalanceModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

Future<List<DashboardGroupBalanceModel>> _fallbackGroupBalances(
  Ref ref,
) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return [];
  }

  final groups = await ref.watch(groupsProvider.future);
  final eventsRepository = ref.watch(eventsRepositoryProvider);
  final reportsRepository = ref.watch(reportsRepositoryProvider);

  final balances = <DashboardGroupBalanceModel>[];
  for (final group in groups) {
    var balance = 0.0;

    try {
      final events = await eventsRepository.list(groupId: group.id);
      final openEvents = events.where((event) => event.status == 'OPEN');

      for (final event in openEvents) {
        try {
          final report = await reportsRepository.getEventReport(event.id);
          final userBalances =
              report.balances.where((item) => item.userId == user.id);
          if (userBalances.isNotEmpty) {
            balance += userBalances.first.balance;
          }
        } catch (_) {
          balance += 0;
        }
      }
    } catch (_) {
      balance = 0;
    }

    balances.add(
      DashboardGroupBalanceModel(
        groupId: group.id,
        groupName: group.name,
        balance: balance,
      ),
    );
  }

  return balances;
}
