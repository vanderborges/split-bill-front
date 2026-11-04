import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/features/events/models/event_model.dart';
import 'package:split_bill_front/features/events/services/events_repository.dart';

EventModel _event(String status) => EventModel(
      id: 'e-$status',
      name: '11/2026',
      description: null,
      type: 'MONTHLY',
      status: status,
      groupId: 'g1',
      monthId: 'm1',
      month: 11,
      year: 2026,
    );

void main() {
  test('todos fechados: "Ocultar fechados" vem desmarcado', () {
    expect(hideClosedByDefault([_event('CLOSED'), _event('CLOSED')]), isFalse);
  });

  test('com evento não fechado: vem marcado', () {
    expect(hideClosedByDefault([_event('OPEN'), _event('CLOSED')]), isTrue);
    expect(hideClosedByDefault([_event('SETTLING'), _event('CLOSED')]), isTrue);
  });

  test('sem evento ou carregando: vem marcado', () {
    expect(hideClosedByDefault(const []), isTrue);
    expect(hideClosedByDefault(null), isTrue);
  });
}
