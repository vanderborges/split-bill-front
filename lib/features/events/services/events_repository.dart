import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../groups/services/groups_repository.dart';
import '../models/event_model.dart';
import '../models/pending_installment_model.dart';

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(dioProvider));
});

final eventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final selectedGroupId = ref.watch(selectedGroupIdProvider);
  // Grupo escolhido no Extrato de onde a pessoa saiu (não está nos grupos
  // ativos): as outras telas caem em "Todos os grupos".
  final groups = await ref.watch(groupsProvider.future);
  final groupId = groups.any((group) => group.id == selectedGroupId)
      ? selectedGroupId
      : null;
  return ref.watch(eventsRepositoryProvider).list(groupId: groupId);
});

/// Eventos do Extrato: os mesmos de [eventsProvider] + os com despesa da
/// pessoa nos grupos de onde ela saiu (só leitura).
final statementEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  // Recarrega junto com a lista normal de eventos.
  ref.watch(eventsProvider);
  final groupId = ref.watch(selectedGroupIdProvider);
  return ref
      .watch(eventsRepositoryProvider)
      .list(groupId: groupId, includeRemoved: true);
});

/// Evento escolhido no Extrato: mesma regra de [selectedEventProvider],
/// sobre [statementEventsProvider].
final statementSelectedEventProvider = FutureProvider<EventModel?>((ref) async {
  final events = await ref.watch(statementEventsProvider.future);
  return pickSelectedEvent(events, ref.watch(selectedEventIdProvider));
});

final openEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final events = await ref.watch(eventsProvider.future);
  return events.where((event) => event.status == 'OPEN').toList();
});

/// Filtro da tela de Eventos: quando true, esconde os eventos já
/// fechados da lista (continuam existindo, só não aparecem ali).
// autoDispose + null: a cada abertura da tela Eventos vale o padrão (marcado,
// menos quando todos os eventos estão fechados - senão a lista viria vazia);
// a escolha da pessoa só vale até sair da tela.
final hideClosedEventsProvider =
    StateProvider.autoDispose<bool?>((ref) => null);

/// Padrão de "Ocultar fechados": marcado, menos com todos os eventos fechados.
bool hideClosedByDefault(List<EventModel>? events) =>
    events == null || events.isEmpty || events.any((event) => !event.isClosed);

/// Mês a oferecer depois de [settled] entrar em pagamento: o seguinte, se o
/// grupo não tem nenhum mês depois dele. Parcela/assinatura já cria o mês
/// seguinte ao abrir o pagamento, então nesse caso não há o que perguntar.
(int month, int year)? nextMonthToOffer(
    EventModel settled, List<EventModel> groupEvents) {
  final month = settled.month;
  final year = settled.year;
  if (settled.type != 'MONTHLY' || month == null || year == null) {
    return null;
  }
  final reference = year * 12 + month;
  final hasLater = groupEvents.any((event) =>
      event.type == 'MONTHLY' &&
      event.month != null &&
      event.year != null &&
      event.year! * 12 + event.month! > reference);
  if (hasLater) {
    return null;
  }
  return month == 12 ? (1, year + 1) : (month + 1, year);
}

final selectedEventIdProvider = StateProvider<String?>((ref) => null);

/// Seleciona o evento pra todas as telas (Eventos, Despesas, Relatório,
/// Extrato) — grava junto o grupo dele, senão a tela seguinte abria com
/// "Todos os grupos" e perdia o contexto.
void selectEvent(WidgetRef ref, {required String groupId, String? eventId}) {
  ref.read(selectedGroupIdProvider.notifier).state = groupId;
  ref.read(selectedEventIdProvider.notifier).state = eventId;
}

final selectedEventProvider = FutureProvider<EventModel?>((ref) async {
  final events = await ref.watch(eventsProvider.future);
  return pickSelectedEvent(events, ref.watch(selectedEventIdProvider));
});

/// O escolhido, se ainda está na lista; senão o padrão: o mais antigo não
/// fechado, ou o mais recente se tudo fechou.
EventModel? pickSelectedEvent(List<EventModel> events, String? selectedId) {
  if (events.isEmpty) {
    return null;
  }
  if (selectedId != null) {
    final selected = events.where((event) => event.id == selectedId);
    if (selected.isNotEmpty) {
      return selected.first;
    }
  }
  // Prefere qualquer evento ainda não fechado (OPEN ou SETTLING) como
  // padrão de exibição, já que SETTLING ainda precisa de atenção (pagamento
  // pendente) mesmo sem aceitar novas despesas. Entre eles abre o MAIS
  // ANTIGO (a lista vem ordenada por criação) - é o que precisa ser
  // acertado primeiro.
  final activeEvents =
      events.where((event) => event.status != 'CLOSED').toList();
  // Tudo fechado: mostra o mais recente.
  return activeEvents.isNotEmpty ? activeEvents.first : events.last;
}

class EventsRepository {
  const EventsRepository(this.dio);

  final Dio dio;

  /// [includeRemoved] (Extrato): também os eventos com despesa da pessoa
  /// nos grupos de onde ela saiu.
  Future<List<EventModel>> list(
      {String? viewerUserId,
      String? groupId,
      bool includeRemoved = false}) async {
    final response = await dio.get<List<dynamic>>(
      '/events',
      queryParameters: {
        if (viewerUserId != null) 'viewerUserId': viewerUserId,
        if (groupId != null) 'groupId': groupId,
        if (includeRemoved) 'includeRemoved': true,
      },
    );
    return response.data!
        .map((item) => EventModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<EventModel> create({
    required String name,
    String? description,
    required String type,
    String? monthId,
    int? month,
    int? year,
    required String groupId,
    List<String>? continueInstallmentGroupIds,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/events',
      data: {
        'name': name,
        'description': description,
        'type': type,
        'monthId': monthId,
        'month': month,
        'year': year,
        'groupId': groupId,
        if (continueInstallmentGroupIds != null)
          'continueInstallmentGroupIds': continueInstallmentGroupIds,
      },
    );
    return EventModel.fromJson(response.data!);
  }

  /// Parcelas/assinaturas do mês anterior que só seguem no mês novo se a
  /// pessoa escolher. Vazio = não há o que perguntar.
  Future<List<PendingInstallmentModel>> pendingInstallments({
    required String groupId,
    required int month,
    required int year,
  }) async {
    final response = await dio.get<List<dynamic>>(
      '/events/pending-installments',
      queryParameters: {'groupId': groupId, 'month': month, 'year': year},
    );
    return response.data!
        .map((item) =>
            PendingInstallmentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Primeira etapa do fechamento: congela o evento para novas despesas e
  /// abre a janela de pagamento (status SETTLING).
  Future<EventModel> startSettlement(String id,
      {String? consolidateToEventId, String? receiverUserId}) async {
    final response = await dio.put<Map<String, dynamic>>(
      '/events/$id/start-settlement',
      data: {
        'consolidateToEventId': consolidateToEventId,
        'receiverUserId': receiverUserId,
        // Diz ao backend que houve escolha (null = sugerir pagamentos);
        // sem isso (app antigo) ele usa o recebedor do grupo.
        'receiverChosen': true,
      },
    );
    return EventModel.fromJson(response.data!);
  }

  /// Fechamento definitivo: só funciona depois de [startSettlement] e com
  /// todos os pagamentos confirmados.
  /// [markAllPaid]: "Concluir evento" do Saldo — o backend marca como pagos
  /// os pagamentos que faltavam antes de fechar.
  Future<EventModel> close(String id, {bool markAllPaid = false}) async {
    final response = await dio.put<Map<String, dynamic>>('/events/$id/close',
        queryParameters: markAllPaid ? {'markAllPaid': true} : null);
    return EventModel.fromJson(response.data!);
  }

  Future<EventModel> reopen(String id) async {
    final response = await dio.put<Map<String, dynamic>>('/events/$id/reopen');
    return EventModel.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await dio.delete<void>('/events/$id');
  }

  /// Manda uma notificação in-app pra quem ainda está devendo nesse
  /// evento. Retorna quantas pessoas receberam o alerta.
  Future<int> sendBillingAlert(String id) async {
    final response =
        await dio.post<Map<String, dynamic>>('/events/$id/billing-alert');
    return response.data!['recipients'] as int;
  }
}
