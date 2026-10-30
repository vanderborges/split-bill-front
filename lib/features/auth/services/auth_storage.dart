import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const authTokenKey = 'split_bill_auth_token';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// "Manter conectado": quando `'true'`, o app entra direto com o token
/// salvo ao abrir, sem passar pela tela de login (o token vale 30 dias no
/// backend). Fica salvo mesmo depois do logout, só pra lembrar a escolha
/// no checkbox.
const rememberMeKey = 'split_bill_remember_me';

/// Sessão guardada pro "Entrar com biometria": continua salva depois do
/// "Sair" (que só tranca o app), então a biometria segue disponível. Some
/// ao trocar de conta (o login novo sobrescreve), ao excluir a conta ou
/// quando a sessão vence/é recusada (30 dias depois do login com senha).
const biometricTokenKey = 'split_bill_biometric_token';
