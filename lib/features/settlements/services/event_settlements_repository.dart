import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../events/services/events_repository.dart';
import '../models/event_settlement_model.dart';

final eventSettlementsRepositoryProvider =
    Provider<EventSettlementsRepository>((ref) {
  return EventSettlementsRepository(ref.watch(dioProvider));
});

final selectedEventSettlementsProvider =
    FutureProvider<List<EventSettlementModel>>((ref) async {
  final event = await ref.watch(selectedEventProvider.future);
  if (event == null) {
    return [];
  }
  return ref.watch(eventSettlementsRepositoryProvider).listByEvent(event.id);
});

class EventSettlementsRepository {
  const EventSettlementsRepository(this.dio);

  final Dio dio;

  Future<List<EventSettlementModel>> listByEvent(String eventId) async {
    final response =
        await dio.get<List<dynamic>>('/events/$eventId/settlements');
    return response.data!
        .map((item) =>
            EventSettlementModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<EventSettlementModel> updateStatus({
    required String eventId,
    required String settlementId,
    required String status,
  }) async {
    final response = await dio.put<Map<String, dynamic>>(
      '/events/$eventId/settlements/$settlementId',
      data: {'status': status},
    );
    return EventSettlementModel.fromJson(response.data!);
  }
}
