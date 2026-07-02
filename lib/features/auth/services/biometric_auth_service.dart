import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_storage.dart';

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService(
    LocalAuthentication(),
    ref.watch(secureStorageProvider),
  );
});

class BiometricAuthService {
  const BiometricAuthService(this.localAuth, this.storage);

  final LocalAuthentication localAuth;
  final FlutterSecureStorage storage;

  Future<bool> canSignInWithBiometrics() async {
    final token = await storage.read(key: authTokenKey);
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final supported = await localAuth.isDeviceSupported();
      final biometrics = await localAuth.getAvailableBiometrics();
      return supported && biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() {
    return localAuth.authenticate(
      localizedReason: 'Use sua biometria para entrar no DividiAi',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
