import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/core/routes/navigation_history.dart';

void main() {
  test(
      'voltar leva à tela anterior (Perfil aberto do Extrato volta pro Extrato)',
      () {
    final history = NavigationHistory()
      ..record('/')
      ..record('/summary')
      ..record('/profile');
    expect(history.popPrevious(), '/summary');
    // Chegou no Extrato pelo voltar: não duplica.
    history.record('/summary');
    expect(history.popPrevious(), '/');
  });

  test('sem tela anterior não volta (usa a tela padrão)', () {
    final history = NavigationHistory()..record('/profile');
    expect(history.popPrevious(), isNull);
  });

  test('voltar a uma tela já visitada corta o caminho (sem ciclo)', () {
    final history = NavigationHistory()
      ..record('/')
      ..record('/events')
      ..record('/expenses')
      ..record('/events');
    expect(history.stack, ['/', '/events']);
  });

  test('login zera o histórico', () {
    final history = NavigationHistory()
      ..record('/')
      ..record('/login')
      ..record('/');
    expect(history.popPrevious(), isNull);
  });
}
