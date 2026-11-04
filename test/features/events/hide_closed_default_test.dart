import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/features/events/models/event_model.dart';
import 'package:split_bill_front/features/events/services/events_repository.dart';

EventModel _event(String status,
        {String type = 'MONTHLY', int? month = 11, int? year = 2026}) =>
    EventModel(
      id: 'e-$status-$month',
      name: '$month/$year',
      description: null,
      type: type,
      status: status,
      groupId: 'g1',
      monthId: 'm1',
      month: month,
      year: year,
    );

void main() {
  group('mês a oferecer depois de abrir o pagamento', () {
    final settled = _event('SETTLING');

    test('sem mês depois: oferece o seguinte', () {
      expect(nextMonthToOffer(settled, [settled]), (12, 2026));
    });

    test('dezembro: vai para janeiro do ano seguinte', () {
      final december = _event('SETTLING', month: 12);
      expect(nextMonthToOffer(december, [december]), (1, 2027));
    });

    test('parcela já criou o mês seguinte: não pergunta', () {
      expect(nextMonthToOffer(settled, [settled, _event('OPEN', month: 12)]),
          null);
    });

    test('mês depois no ano seguinte também conta', () {
      expect(
          nextMonthToOffer(
              settled, [settled, _event('OPEN', month: 1, year: 2027)]),
          null);
    });

    test('mês anterior ou evento avulso não contam como mês depois', () {
      expect(
          nextMonthToOffer(settled, [
            settled,
            _event('CLOSED', month: 10),
            _event('OPEN', type: 'SPORADIC', month: null, year: null),
          ]),
          (12, 2026));
    });

    test('evento avulso não oferece mês', () {
      final sporadic =
          _event('SETTLING', type: 'SPORADIC', month: null, year: null);
      expect(nextMonthToOffer(sporadic, [sporadic]), null);
    });
  });

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
