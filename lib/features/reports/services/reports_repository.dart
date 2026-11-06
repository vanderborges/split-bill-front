import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/prefetch_cache.dart';
import '../../events/services/events_repository.dart';
import '../../groups/services/groups_repository.dart';
import '../../months/services/months_repository.dart';
import '../../settlements/models/event_settlement_model.dart';
import '../models/balance_expense_detail_model.dart';
import '../models/monthly_report_model.dart';
import '../models/payment_suggestion_model.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dioProvider));
});

final currentMonthReportProvider =
    FutureProvider<MonthlyReportModel?>((ref) async {
  final month = await ref.watch(currentMonthProvider.future);
  if (month == null) {
    return null;
  }
  return ref.watch(reportsRepositoryProvider).getMonthlyReport(month.id);
});

final selectedEventReportProvider =
    FutureProvider<MonthlyReportModel?>((ref) async {
  final event = await ref.watch(selectedEventProvider.future);
  if (event == null) {
    return null;
  }
  return ref.watch(reportsRepositoryProvider).getEventReport(event.id);
});

/// Relatório de um evento qualquer (Extrato com "Todos os eventos"). Usa o
/// que já veio no [statementPrefetchProvider], se tiver.
final eventReportProvider =
    FutureProvider.family<MonthlyReportModel, String>((ref, eventId) async {
  final cached = ref
      .read(prefetchCacheProvider)
      .take<MonthlyReportModel>(statementReportKey(eventId));
  if (cached.found && cached.value != null) {
    return cached.value!;
  }
  return ref.watch(reportsRepositoryProvider).getEventReport(eventId);
});

/// Extrato com "Todos os eventos": uma chamada só (`GET /statement`) traz o
/// relatório e os acertos de todos os eventos e o papel em cada grupo, que
/// ficam no [PrefetchCache] para os cards. Antes eram 2 chamadas por evento
/// e 1 por grupo (113 para quem tem 48 eventos). Mesmo filtro de grupo de
/// [statementEventsProvider], e recarrega junto com ele.
final statementPrefetchProvider = FutureProvider<void>((ref) async {
  // Sem esperar a lista de eventos: as duas chamadas saem juntas (antes era
  // uma depois da outra, duas idas e voltas ao servidor). Só fica
  // dependente dela para recarregar junto.
  ref.watch(statementEventsProvider.future).ignore();
  final groupId = ref.watch(selectedGroupIdProvider);
  final cache = ref.read(prefetchCacheProvider);
  final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
    '/statement',
    queryParameters: {if (groupId != null) 'groupId': groupId},
  );
  final data = response.data!;
  for (final item in data['events'] as List<dynamic>) {
    final entry = item as Map<String, dynamic>;
    final eventId = entry['eventId'] as String;
    cache.put(statementReportKey(eventId),
        MonthlyReportModel.fromJson(entry['report'] as Map<String, dynamic>));
    cache.put(
        statementSettlementsKey(eventId),
        (entry['settlements'] as List<dynamic>)
            .map((row) =>
                EventSettlementModel.fromJson(row as Map<String, dynamic>))
            .toList());
  }
  (data['groupRoles'] as Map<String, dynamic>).forEach(
      (groupId, role) => cache.put(statementRoleKey(groupId), role as String?));
});

class ReportsRepository {
  const ReportsRepository(this.dio);

  final Dio dio;

  Future<MonthlyReportModel> getMonthlyReport(String monthId) async {
    final response =
        await dio.get<Map<String, dynamic>>('/reports/months/$monthId');
    return MonthlyReportModel.fromJson(response.data!);
  }

  Future<MonthlyReportModel> getEventReport(String eventId) async {
    final response =
        await dio.get<Map<String, dynamic>>('/reports/events/$eventId');
    return MonthlyReportModel.fromJson(response.data!);
  }

  Future<List<BalanceExpenseDetailModel>> getBalanceDetails({
    required String eventId,
    required String userId,
    // Só as despesas da própria pessoa, sem quem é vinculado a ela.
    bool onlyUser = false,
  }) async {
    final response = await dio.get<List<dynamic>>(
        '/reports/events/$eventId/balances/$userId/details',
        queryParameters: onlyUser ? {'onlyUser': true} : null);
    return response.data!
        .map((item) =>
            BalanceExpenseDetailModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Sugestão de "quem paga quanto pra quem" — só exibição, não afeta o
  /// acerto/saldo calculado normalmente.
  Future<List<PaymentSuggestionModel>> getPaymentSuggestions(
      String eventId) async {
    final response = await dio
        .get<List<dynamic>>('/reports/events/$eventId/payment-suggestions');
    return response.data!
        .map((item) =>
            PaymentSuggestionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
