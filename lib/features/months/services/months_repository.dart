import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../models/month_model.dart';

final monthsRepositoryProvider = Provider<MonthsRepository>((ref) {
  return MonthsRepository(ref.watch(dioProvider));
});

final monthsProvider = FutureProvider<List<MonthModel>>((ref) {
  return ref.watch(monthsRepositoryProvider).list();
});

final currentMonthProvider = FutureProvider<MonthModel?>((ref) async {
  final months = await ref.watch(monthsProvider.future);
  if (months.isEmpty) {
    return null;
  }
  final openMonths = months.where((month) => month.status == 'OPEN').toList();
  final source = openMonths.isNotEmpty ? openMonths : months;
  source.sort((a, b) {
    final yearCompare = b.year.compareTo(a.year);
    if (yearCompare != 0) {
      return yearCompare;
    }
    return b.month.compareTo(a.month);
  });
  return source.first;
});

class MonthsRepository {
  const MonthsRepository(this.dio);

  final Dio dio;

  Future<List<MonthModel>> list() async {
    final response = await dio.get<List<dynamic>>('/months');
    return response.data!
        .map((item) => MonthModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MonthModel> create({required int month, required int year}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/months',
      data: {'month': month, 'year': year},
    );
    return MonthModel.fromJson(response.data!);
  }

  Future<MonthModel> close(String id) async {
    final response = await dio.put<Map<String, dynamic>>('/months/$id/close');
    return MonthModel.fromJson(response.data!);
  }

  Future<MonthModel> reopen(String id) async {
    final response = await dio.put<Map<String, dynamic>>('/months/$id/reopen');
    return MonthModel.fromJson(response.data!);
  }
}
