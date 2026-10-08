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
