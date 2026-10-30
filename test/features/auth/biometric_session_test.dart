import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/features/auth/services/auth_repository.dart';
import 'package:split_bill_front/features/auth/services/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStorage storage;
  late AuthRepository auth;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const FlutterSecureStorage();
    auth = AuthRepository(Dio(), storage);
    // Como fica depois de um login com senha.
    await storage.write(key: authTokenKey, value: 'sessao');
    await storage.write(key: biometricTokenKey, value: 'sessao');
  });

  test('"Sair" tranca o app mas mantém a sessão da biometria', () async {
    await auth.logout(keepBiometric: true);
    expect(await auth.token(), isNull);
    expect(await auth.biometricToken(), 'sessao');

    expect(await auth.restoreBiometricSession(), isTrue);
    expect(await auth.token(), 'sessao');
  });

  test('quem entrou antes desta versão também mantém a biometria', () async {
    await storage.delete(key: biometricTokenKey);
    await auth.logout(keepBiometric: true);
    expect(await auth.biometricToken(), 'sessao');
  });

  test('sessão recusada / conta excluída apaga também a da biometria',
      () async {
    await auth.logout();
    expect(await auth.token(), isNull);
    expect(await auth.biometricToken(), isNull);
    expect(await auth.restoreBiometricSession(), isFalse);
  });
}
