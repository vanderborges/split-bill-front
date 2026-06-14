import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../events/services/events_repository.dart';
import '../../months/services/months_repository.dart';
import '../models/expense_model.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(dioProvider));
});

final currentMonthExpensesProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  final month = await ref.watch(currentMonthProvider.future);
  if (month == null) {
    return [];
  }
  return ref.watch(expensesRepositoryProvider).listByMonth(month.id);
});

final selectedEventExpensesProvider = FutureProvider<List<ExpenseModel>>((ref) async {
  final event = await ref.watch(selectedEventProvider.future);
  if (event == null) {
    return [];
  }
  return ref.watch(expensesRepositoryProvider).listByEvent(event.id);
});

class ExpensesRepository {
  const ExpensesRepository(this.dio);

  final Dio dio;

  Future<List<ExpenseModel>> listByMonth(String monthId) async {
    final response = await dio.get<List<dynamic>>(
      '/expenses',
      queryParameters: {'monthId': monthId},
    );
    return response.data!
        .map((item) => ExpenseModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExpenseModel>> listByEvent(String eventId) async {
    final response = await dio.get<List<dynamic>>(
      '/expenses',
      queryParameters: {'eventId': eventId},
    );
    return response.data!
        .map((item) => ExpenseModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseModel> create({
    required String description,
    required double amount,
    required DateTime expenseDate,
    required String category,
    String? monthId,
    String? eventId,
    int? installments,
    required List<String> participantIds,
    required Map<String, double> payerAmounts,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/expenses',
        data: _toRequestBody(
          description: description,
          amount: amount,
          expenseDate: expenseDate,
          category: category,
          monthId: monthId,
          eventId: eventId,
          installments: installments,
          participantIds: participantIds,
          payerAmounts: payerAmounts,
        ),
      );
      return ExpenseModel.fromJson(response.data!);
    } on DioException catch (error) {
      throw Exception(_errorMessage(error));
    }
  }

  Future<ExpenseModel> update({
    required String id,
    required String description,
    required double amount,
    required DateTime expenseDate,
    required String category,
    String? monthId,
    String? eventId,
    required List<String> participantIds,
    required Map<String, double> payerAmounts,
  }) async {
    try {
      final response = await dio.put<Map<String, dynamic>>(
        '/expenses/$id',
        data: _toRequestBody(
          description: description,
          amount: amount,
          expenseDate: expenseDate,
          category: category,
          monthId: monthId,
          eventId: eventId,
          participantIds: participantIds,
          payerAmounts: payerAmounts,
        ),
      );
      return ExpenseModel.fromJson(response.data!);
    } on DioException catch (error) {
      throw Exception(_errorMessage(error));
    }
  }

  Future<void> delete(String id, String adminUserId) async {
    try {
      await dio.delete<void>(
        '/expenses/$id',
        queryParameters: {'adminUserId': adminUserId},
      );
    } on DioException catch (error) {
      throw Exception(_errorMessage(error));
    }
  }

  Map<String, dynamic> _toRequestBody({
    required String description,
    required double amount,
    required DateTime expenseDate,
    required String category,
    String? monthId,
    String? eventId,
    int? installments,
    required List<String> participantIds,
    required Map<String, double> payerAmounts,
  }) {
    final payers = payerAmounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'userId': entry.key, 'amount': entry.value})
        .toList();
    return {
      'description': description,
      'amount': amount,
      'expenseDate': expenseDate.toIso8601String().substring(0, 10),
      'category': category,
      'payerId': payers.isEmpty ? null : payers.first['userId'],
      'monthId': monthId,
      'eventId': eventId,
      'participantIds': participantIds,
      'payers': payers,
      'installments': installments,
    };
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return error.message ?? 'Erro ao comunicar com a API';
  }
}
