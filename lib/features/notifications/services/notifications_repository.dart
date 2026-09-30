import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../models/notification_model.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(dioProvider));
});

final notificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  return ref.watch(notificationsRepositoryProvider).list();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];
  return notifications.where((notification) => !notification.isRead).length;
});

class NotificationsRepository {
  const NotificationsRepository(this.dio);

  final Dio dio;

  Future<List<NotificationModel>> list() async {
    final response = await dio.get<List<dynamic>>('/notifications');
    return response.data!
        .map((item) =>
            NotificationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    await dio.put<void>('/notifications/$id/read');
  }
}
