import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Histórico das telas visitadas. As rotas usam `context.go` (sem pilha de
/// telas), então a seta de voltar não tinha pra onde voltar e cada tela
/// mandava pra uma fixa (ex.: Perfil sempre pro Início). Com o histórico,
/// voltar leva à tela anterior de verdade.
class NavigationHistory {
  final List<String> _stack = [];

  /// Chamado a cada troca de rota (ver `appRouterProvider`).
  void record(String location) {
    // Login/cadastro começam do zero (troca de conta, sair).
    if (location.startsWith('/login') || location.startsWith('/register')) {
      _stack.clear();
      return;
    }
    if (_stack.isNotEmpty && _stack.last == location) {
      return;
    }
    // Voltou pra uma tela que já estava no caminho (ex.: pela barra de
    // menus): o caminho volta até ela, sem ficar em ciclo.
    final index = _stack.indexOf(location);
    if (index >= 0) {
      _stack.removeRange(index + 1, _stack.length);
    } else {
      _stack.add(location);
    }
    if (_stack.length > 30) {
      _stack.removeAt(0);
    }
  }

  /// Tela anterior (tirando a atual do histórico), ou null se não há.
  String? popPrevious() {
    if (_stack.length < 2) {
      return null;
    }
    _stack.removeLast();
    return _stack.last;
  }

  /// Sem tela anterior (ex.: abriu direto pelo link): começa de novo pela
  /// tela de destino.
  void resetTo(String location) {
    _stack
      ..clear()
      ..add(location);
  }

  @visibleForTesting
  List<String> get stack => List.unmodifiable(_stack);
}

final navigationHistory = NavigationHistory();

/// Seta de voltar / arrastar da borda / voltar do Android: tela anterior;
/// sem histórico, [fallback].
void goBack(BuildContext context, {required String fallback}) {
  final target = navigationHistory.popPrevious();
  if (target == null) {
    navigationHistory.resetTo(fallback);
  }
  context.go(target ?? fallback);
}
