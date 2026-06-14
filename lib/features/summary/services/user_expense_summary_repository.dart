import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../models/user_expense_summary_model.dart';

final userExpenseSummaryRepositoryProvider = Provider<UserExpenseSummaryRepository>((ref) {
  return UserExpenseSummaryRepository(ref.watch(dioProvider));
});

class UserExpenseSummaryRepository {
  const UserExpenseSummaryRepository(this.dio);

  final Dio dio;

  Future<UserExpenseSummaryModel> get({
    required String userId,
    DateTime? from,
    DateTime? to,
    String? category,
    String? eventId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/users/$userId/expense-summary',
      queryParameters: {
        if (from != null) 'from': from.toIso8601String().substring(0, 10),
        if (to != null) 'to': to.toIso8601String().substring(0, 10),
        if (category != null && category.isNotEmpty) 'category': category,
        if (eventId != null) 'eventId': eventId,
      },
    );
    return UserExpenseSummaryModel.fromJson(response.data!);
  }
}
