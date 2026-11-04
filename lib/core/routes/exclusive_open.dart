bool _opening = false;

/// Tem tela, pop-up ou formulário aberto (ou carregando para abrir).
bool get isExclusiveOpen => _opening;

/// Abre uma tela de cada vez: enquanto [open] não terminar, novas chamadas
/// são ignoradas. Vários formulários buscam dados antes de abrir (grupos,
/// participantes, categorias) e, nesse meio tempo, a tela de trás continua
/// aceitando toques: sem a trava, cada toque abria uma tela por cima da outra.
///
/// Usar no que é aberto a partir da tela de fundo. O que abre de dentro de
/// um formulário já aberto (ex.: "Nova categoria") não passa por aqui.
Future<void> openExclusive(Future<void> Function() open) async {
  if (_opening) {
    return;
  }
  _opening = true;
  try {
    await open();
  } finally {
    _opening = false;
  }
}
