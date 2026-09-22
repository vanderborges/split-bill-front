import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../groups/services/groups_repository.dart';
import '../models/event_model.dart';

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(dioProvider));
});

final eventsProvider = FutureProvider<List<EventModel>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider);
  return ref.watch(eventsRepositoryProvider).list(groupId: groupId);
});

final openEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final events = await ref.watch(eventsProvider.future);
  return events.where((event) => event.status == 'OPEN').toList();
});

final selectedEventIdProvider = StateProvider<String?>((ref) => null);

final selectedEventProvider = FutureProvider<EventModel?>((ref) async {
  final events = await ref.watch(eventsProvider.future);
  if (events.isEmpty) {
    return null;
  }
  final selectedId = ref.watch(selectedEventIdProvider);
  if (selectedId != null) {
    final selected = events.where((event) => event.id == selectedId);
    if (selected.isNotEmpty) {
      return selected.first;
    }
  }
  final openEvents = events.where((event) => event.status == 'OPEN').toList();
  final source = openEvents.isNotEmpty ? openEvents : events;
  return source.last;
});

class EventsRepository {
  const EventsRepository(this.dio);

  final Dio dio;

  Future<List<EventModel>> list({String? viewerUserId, String? groupId}) async {
    final response = await dio.get<List<dynamic>>(
      '/events',
      queryParameters: {
        if (viewerUserId != null) 'viewerUserId': viewerUserId,
        if (groupId != null) 'groupId': groupId,
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
      },
    );
    return EventModel.fromJson(response.data!);
  }

  Future<EventModel> close(String id, {String? consolidateToEventId}) async {
    final response = await dio.put<Map<String, dynamic>>(
      '/events/$id/close',
      data: {'consolidateToEventId': consolidateToEventId},
    );
    return EventModel.fromJson(response.data!);
  }

  Future<EventModel> reopen(String id) async {
    final response = await dio.put<Map<String, dynamic>>('/events/$id/reopen');
    return EventModel.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await dio.delete<void>('/events/$id');
  }
}
