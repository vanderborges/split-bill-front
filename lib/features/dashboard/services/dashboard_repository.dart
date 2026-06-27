import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../models/dashboard_group_balance_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dioProvider));
});

final dashboardGroupBalancesProvider =
    FutureProvider<List<DashboardGroupBalanceModel>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getGroupBalances();
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
