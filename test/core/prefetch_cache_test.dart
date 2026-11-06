import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_front/core/network/dio_provider.dart';
import 'package:split_bill_front/core/network/prefetch_cache.dart';
import 'package:split_bill_front/features/events/models/event_model.dart';
import 'package:split_bill_front/features/events/services/events_repository.dart';
import 'package:split_bill_front/features/reports/models/monthly_report_model.dart';
import 'package:split_bill_front/features/reports/services/reports_repository.dart';

MonthlyReportModel _report(String name) => MonthlyReportModel.fromJson({
      'monthId': null,
      'eventId': 'e1',
      'eventName': name,
      'groupId': 'g1',
      'groupName': 'Grupo',
      'month': 11,
      'year': 2026,
      'status': 'OPEN',
      'totalExpenses': 10,
      'balances': <dynamic>[],
    });

class _CountingReports extends ReportsRepository {
  _CountingReports() : super(Dio());

  var calls = 0;

  @override
  Future<MonthlyReportModel> getEventReport(String eventId) async {
    calls++;
    return _report('do servidor');
  }
}

/// Responde o /statement vazio e conta as chamadas.
class _CountingStatement extends Interceptor {
  var calls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    calls++;
    handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'events': <dynamic>[], 'groupRoles': <String, dynamic>{}}));
  }
}

void main() {
  test(
      'Extrato sai junto com a lista de eventos (sem esperar) e chama o '
      '/statement uma vez só', () async {
    final statement = _CountingStatement();
    final eventsDone = Completer<List<EventModel>>();
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(Dio()..interceptors.add(statement)),
      statementEventsProvider.overrideWith((ref) => eventsDone.future),
    ]);
    addTearDown(container.dispose);

    final prefetch = container.read(statementPrefetchProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // A lista de eventos ainda não chegou e o /statement já foi pedido.
    expect(statement.calls, 1);

    eventsDone.complete([]);
    await prefetch;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await container.read(statementPrefetchProvider.future);
    expect(statement.calls, 1);
  });

  test('resposta guardada vale uma vez só', () {
    final cache = PrefetchCache()..put('k', 'valor');
    expect(cache.take<String>('k'), (found: true, value: 'valor'));
    expect(cache.take<String>('k').found, isFalse);
  });

  test('resposta velha não é usada', () {
    var now = DateTime(2026, 11, 6, 12);
    final cache = PrefetchCache(clock: () => now)..put('k', 'valor');
    now = now.add(PrefetchCache.maxAge + const Duration(seconds: 1));
    expect(cache.take<String>('k').found, isFalse);
  });

  test('null guardado conta como encontrado (papel de quem saiu do grupo)', () {
    final cache = PrefetchCache()..put('role:g1', null);
    expect(cache.take<String>('role:g1'), (found: true, value: null));
  });

  test(
      'card do Extrato usa o que veio no /statement e, depois de atualizar, '
      'busca do servidor', () async {
    final reports = _CountingReports();
    final container = ProviderContainer(overrides: [
      reportsRepositoryProvider.overrideWithValue(reports),
    ]);
    addTearDown(container.dispose);
    container
        .read(prefetchCacheProvider)
        .put(statementReportKey('e1'), _report('do Extrato'));

    final first = await container.read(eventReportProvider('e1').future);
    expect(first.eventName, 'do Extrato');
    expect(reports.calls, 0);

    // Ex.: pagamento registrado invalida o relatório do evento.
    container.invalidate(eventReportProvider('e1'));
    final refreshed = await container.read(eventReportProvider('e1').future);
    expect(refreshed.eventName, 'do servidor');
    expect(reports.calls, 1);
  });
}
