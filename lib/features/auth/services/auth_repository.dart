import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_provider.dart';
import '../models/auth_session.dart';
import 'auth_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});

class AuthRepository {
  const AuthRepository(this.dio, this.storage);

  final Dio dio;
  final FlutterSecureStorage storage;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await storage.delete(key: authTokenKey);
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );
    final session = AuthSession.fromJson(response.data!);
    await storage.write(key: authTokenKey, value: session.token);
    return session;
  }

  Future<void> logout() async {
    await storage.delete(key: authTokenKey);
  }

  Future<String?> token() {
    return storage.read(key: authTokenKey);
  }
}
