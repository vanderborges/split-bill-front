import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../events/services/events_repository.dart';
import '../../months/services/months_repository.dart';
import '../models/monthly_report_model.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dioProvider));
});

final currentMonthReportProvider = FutureProvider<MonthlyReportModel?>((ref) async {
  final month = await ref.watch(currentMonthProvider.future);
  if (month == null) {
    return null;
  }
  return ref.watch(reportsRepositoryProvider).getMonthlyReport(month.id);
});

final selectedEventReportProvider = FutureProvider<MonthlyReportModel?>((ref) async {
  final event = await ref.watch(selectedEventProvider.future);
  if (event == null) {
    return null;
  }
  return ref.watch(reportsRepositoryProvider).getEventReport(event.id);
});

class ReportsRepository {
  const ReportsRepository(this.dio);

  final Dio dio;

  Future<MonthlyReportModel> getMonthlyReport(String monthId) async {
    final response = await dio.get<Map<String, dynamic>>('/reports/months/$monthId');
    return MonthlyReportModel.fromJson(response.data!);
  }

  Future<MonthlyReportModel> getEventReport(String eventId) async {
    final response = await dio.get<Map<String, dynamic>>('/reports/events/$eventId');
    return MonthlyReportModel.fromJson(response.data!);
  }
}
