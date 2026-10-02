import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sinaliza que a tela de eventos deve abrir o formulário de novo evento
/// assim que terminar de carregar.
///
/// Usado quando alguém tenta lançar uma despesa num grupo sem nenhum
/// evento aberto e escolhe "Sim, criar evento" — leva direto pro
/// formulário em vez de só abrir a lista de eventos.
final pendingAutoOpenEventProvider = StateProvider<bool>((ref) => false);
