import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../models/user_model.dart';
import '../models/user_option_model.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(dioProvider));
});

final usersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(usersRepositoryProvider).list();
});

final userOptionsProvider = FutureProvider<List<UserOptionModel>>((ref) {
  return ref.watch(usersRepositoryProvider).options();
});

class UsersRepository {
  const UsersRepository(this.dio);

  final Dio dio;

  Future<List<UserModel>> list() async {
    final response = await dio.get<List<dynamic>>('/users');
    return response.data!
        .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserOptionModel>> options() async {
    final response = await dio.get<List<dynamic>>('/users/options');
    return response.data!
        .map((item) => UserOptionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> get(String id) async {
    final response = await dio.get<Map<String, dynamic>>('/users/$id');
    return UserModel.fromJson(response.data!);
  }

  Future<UserModel> create({
    required String fullName,
    required String nickname,
    required String email,
    required String phone,
    required String pixKey,
    required String password,
    String? billingUserId,
    required bool admin,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/users',
      data: {
        'fullName': fullName,
        'nickname': nickname,
        'email': email,
        'phone': phone,
        'pixKey': pixKey,
        'password': password,
        'billingUserId': billingUserId,
        'admin': admin,
      },
    );
    return UserModel.fromJson(response.data!);
  }

  Future<UserModel> update({
    required String id,
    required String fullName,
    required String nickname,
    required String email,
    required String phone,
    required String pixKey,
    required String? billingUserId,
    required bool admin,
    required bool active,
  }) async {
    final response = await dio.put<Map<String, dynamic>>(
      '/users/$id',
      data: {
        'fullName': fullName,
        'nickname': nickname,
        'email': email,
        'phone': phone,
        'pixKey': pixKey,
        'billingUserId': billingUserId,
        'admin': admin,
        'active': active,
      },
    );
    return UserModel.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await dio.delete<void>('/users/$id');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await dio.put<void>(
      '/users/me/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> resetPassword({
    required String id,
    required String newPassword,
  }) async {
    await dio.put<void>(
      '/users/$id/password/reset',
      data: {'newPassword': newPassword},
    );
  }
}
