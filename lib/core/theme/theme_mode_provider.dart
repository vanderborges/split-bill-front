import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/services/auth_storage.dart';

const _themeModeKey = 'split_bill_theme_mode';

/// Modo de tela escolhido no Perfil (claro, escuro ou padrão do sistema).
/// Fica salvo no aparelho; começa no padrão do sistema.
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref)..load();
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._ref) : super(ThemeMode.system);

  final Ref _ref;

  Future<void> load() async {
    try {
      final saved =
          await _ref.read(secureStorageProvider).read(key: _themeModeKey);
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Sem acesso ao armazenamento: fica no padrão do sistema.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await _ref
          .read(secureStorageProvider)
          .write(key: _themeModeKey, value: mode.name);
    } catch (_) {
      // Não salvou: vale só até fechar o app.
    }
  }
}
