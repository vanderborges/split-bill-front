import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../events/services/events_repository.dart';
import '../../months/services/months_repository.dart';
import '../models/expense_model.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(dioProvider));
});

/// Filtro da tela de despesas: quando true, mostra só as despesas em que o
/// usuário logado participa (pagou ou consumiu), em vez de todas do evento.
/// Começa marcado e, por ser autoDispose, volta a marcado toda vez que a
/// tela de Despesas é aberta de novo.
final showOnlyMyExpensesProvider =
    StateProvider.autoDispose<bool>((ref) => true);

/// Visão da tela de despesas: false = lista de despesas, true = saldo do
/// evento (o mesmo conteúdo do Relatório). Volta para despesas ao reabrir.
final showEventBalanceProvider =
    StateProvider.autoDispose<bool>((ref) => false);

/// Rolou a lista de despesas/saldo pra baixo: esconde os controles do topo
/// (Despesas/Saldo, filtro, Fechar evento), deixando só o seletor de
/// evento. Rolar pra cima mostra de novo.
final expensesHeaderCollapsedProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final currentMonthExpensesProvider =
    FutureProvider<List<ExpenseModel>>((ref) async {
  final month = await ref.watch(currentMonthProvider.future);
  if (month == null) {
    return [];
  }
  return ref.watch(expensesRepositoryProvider).listByMonth(month.id);
});

final selectedEventExpensesProvider =
    FutureProvider<List<ExpenseModel>>((ref) async {
  final event = await ref.watch(selectedEventProvider.future);
  if (event == null) {
    return [];
  }
  return ref.watch(expensesRepositoryProvider).listByEvent(event.id);
});

class ExpensesRepository {
  const ExpensesRepository(this.dio);

  final Dio dio;

  Future<List<ExpenseModel>> listByMonth(String monthId) async {
    final response = await dio.get<List<dynamic>>(
      '/expenses',
      queryParameters: {'monthId': monthId},
    );
    return response.data!
        .map((item) => ExpenseModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExpenseModel>> listByEvent(String eventId) async {
    final response = await dio.get<List<dynamic>>(
      '/expenses',
      queryParameters: {'eventId': eventId},
    );
    return response.data!
        .map((item) => ExpenseModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseModel> create({
    required String description,
    required double amount,
    required DateTime expenseDate,
    required String category,
    String? monthId,
    String? eventId,
    int? installments,
    bool subscription = false,
    required List<String> participantIds,
    required Map<String, int> participantShareCounts,
    required Map<String, String> participantShareDescriptions,
    Map<String, double>? participantShareAmounts,
    required Map<String, double> payerAmounts,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/expenses',
      data: _toRequestBody(
        description: description,
        amount: amount,
        expenseDate: expenseDate,
        category: category,
        monthId: monthId,
        eventId: eventId,
        installments: installments,
        subscription: subscription,
        participantIds: participantIds,
        participantShareCounts: participantShareCounts,
        participantShareDescriptions: participantShareDescriptions,
        participantShareAmounts: participantShareAmounts,
        payerAmounts: payerAmounts,
      ),
    );
    return ExpenseModel.fromJson(response.data!);
  }

  /// Finaliza uma assinatura a partir do mês corrente — admin ou quem
  /// cadastrou. A despesa deste mês continua existindo, só para de gerar
  /// a próxima no mês seguinte.
  Future<ExpenseModel> cancelSubscription(String id) async {
    final response = await dio
        .put<Map<String, dynamic>>('/expenses/$id/cancel-subscription');
    return ExpenseModel.fromJson(response.data!);
  }

  Future<ExpenseModel> update({
    required String id,
    required String description,
    required double amount,
    required DateTime expenseDate,
    required String category,
    String? monthId,
    String? eventId,
    required List<String> participantIds,
    required Map<String, int> participantShareCounts,
    required Map<String, String> participantShareDescriptions,
    Map<String, double>? participantShareAmounts,
    required Map<String, double> payerAmounts,
  }) async {
    final response = await dio.put<Map<String, dynamic>>(
      '/expenses/$id',
      data: _toRequestBody(
        description: description,
        amount: amount,
        expenseDate: expenseDate,
        category: category,
        monthId: monthId,
        eventId: eventId,
        participantIds: participantIds,
        participantShareCounts: participantShareCounts,
        participantShareDescriptions: participantShareDescriptions,
        participantShareAmounts: participantShareAmounts,
        payerAmounts: payerAmounts,
      ),
    );
    return ExpenseModel.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await dio.delete<void>('/expenses/$id');
  }

  Map<String, dynamic> _toRequestBody({
    required String description,
    required double amount,
    required DateTime expenseDate,
    required String category,
    String? monthId,
    String? eventId,
    int? installments,
    bool subscription = false,
    required List<String> participantIds,
    required Map<String, int> participantShareCounts,
    required Map<String, String> participantShareDescriptions,
    Map<String, double>? participantShareAmounts,
    required Map<String, double> payerAmounts,
  }) {
    final payers = payerAmounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'userId': entry.key, 'amount': entry.value})
        .toList();
    final participants = participantIds
        .map((id) => {
              'userId': id,
              'shareCount': participantShareCounts[id] ?? 1,
              'shareDescription': participantShareDescriptions[id],
              // Divisão por valor: cada um com o valor digitado (o backend
              // exige valor de todos e soma batendo com o total).
              if (participantShareAmounts != null)
                'shareAmount': participantShareAmounts[id],
            })
        .toList();
    final hasCustomShares = participantShareAmounts != null ||
        participants.any((participant) =>
            participant['shareCount'] != 1 ||
            participant['shareDescription'] != null);
    return {
      'description': description,
      'amount': amount,
      'expenseDate': expenseDate.toIso8601String().substring(0, 10),
      'category': category,
      'payerId': payers.isEmpty ? null : payers.first['userId'],
      'monthId': monthId,
      'eventId': eventId,
      if (!hasCustomShares) 'participantIds': participantIds,
      'participants': participants,
      'payers': payers,
      'installments': installments,
      'subscription': subscription,
    };
  }
}
