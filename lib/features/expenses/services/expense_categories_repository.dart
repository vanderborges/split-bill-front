import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../models/expense_category_model.dart';

final expenseCategoriesRepositoryProvider = Provider<ExpenseCategoriesRepository>((ref) {
  return ExpenseCategoriesRepository(ref.watch(dioProvider));
});

final expenseCategoriesProvider = FutureProvider<List<ExpenseCategoryModel>>((ref) {
  return ref.watch(expenseCategoriesRepositoryProvider).list();
});

class ExpenseCategoriesRepository {
  const ExpenseCategoriesRepository(this.dio);

  final Dio dio;

  Future<List<ExpenseCategoryModel>> list() async {
    final response = await dio.get<List<dynamic>>('/expense-categories');
    return response.data!
        .map((item) => ExpenseCategoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseCategoryModel> create(String name) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/expense-categories',
      data: {'name': name},
    );
    return ExpenseCategoryModel.fromJson(response.data!);
  }
}
