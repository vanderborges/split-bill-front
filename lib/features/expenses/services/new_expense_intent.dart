import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sinaliza que a tela de despesas deve abrir o formulário de nova despesa
/// assim que terminar de carregar.
///
/// Existe para que o CTA "Nova despesa" da Home leve o usuário direto ao
/// formulário, em vez de só abrir a lista de despesas e exigir um segundo
/// toque no botão "+" — ver docs/ux-roadmap-dividiai.md (regra "menos
/// passos + menos decisões").
final pendingAutoOpenExpenseProvider = StateProvider<bool>((ref) => false);
