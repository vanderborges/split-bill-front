import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_provider.dart';
import '../../notifications/services/push_service.dart';
import '../models/auth_session.dart';
import 'auth_storage.dart';
import '../../users/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
    beforeLogout: () => ref.read(pushServiceProvider).unregisterDevice(),
  );
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  final token = await repository.token();
  if (token == null || token.isEmpty) {
    return null;
  }
  return repository.me();
});

class AuthRepository {
  const AuthRepository(this.dio, this.storage, {this.beforeLogout});

  final Dio dio;
  final FlutterSecureStorage storage;

  /// Roda antes de apagar o token de login (remove o aparelho do push,
  /// chamada que precisa ir autenticada).
  final Future<void> Function()? beforeLogout;

  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
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
    // Mesma sessão guardada pra biometria (troca de conta sobrescreve).
    await storage.write(key: biometricTokenKey, value: session.token);
    await storage.write(key: rememberMeKey, value: rememberMe.toString());
    return session;
  }

  /// [keepBiometric] ("Sair" do menu): só tranca o app - a sessão fica
  /// guardada pro "Entrar com biometria". false (sessão vencida/recusada,
  /// conta excluída): apaga tudo.
  Future<void> logout({bool keepBiometric = false}) async {
    await beforeLogout?.call();
    if (keepBiometric) {
      // Quem entrou antes desta versão ainda não tem a cópia guardada.
      final current = await storage.read(key: authTokenKey);
      if (current != null && current.isNotEmpty) {
        await storage.write(key: biometricTokenKey, value: current);
      }
    }
    await storage.delete(key: authTokenKey);
    if (!keepBiometric) {
      await storage.delete(key: biometricTokenKey);
    }
  }

  /// Sessão guardada pra biometria (ou a ativa, de quem ainda não saiu).
  Future<String?> biometricToken() async {
    final saved = await storage.read(key: biometricTokenKey);
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    return storage.read(key: authTokenKey);
  }

  /// Biometria confirmada: volta a usar a sessão guardada.
  Future<bool> restoreBiometricSession() async {
    final saved = await biometricToken();
    if (saved == null || saved.isEmpty) {
      return false;
    }
    await storage.write(key: authTokenKey, value: saved);
    return true;
  }

  Future<bool> rememberMe() async {
    final value = await storage.read(key: rememberMeKey);
    return value == null || value == 'true';
  }

  Future<String?> token() {
    return storage.read(key: authTokenKey);
  }

  Future<UserModel> me() async {
    final response = await dio.get<Map<String, dynamic>>('/auth/me');
    return UserModel.fromJson(response.data!);
  }
}
