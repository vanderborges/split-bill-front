import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/api_error.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../models/notification_model.dart';
import '../services/notifications_repository.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return AppScaffold(
      title: 'Notificações',
      child: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Nenhuma notificação por aqui.',
              message: 'Avisos sobre pagamentos pendentes aparecem aqui.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                leading: Icon(
                  notification.isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  color: notification.isRead
                      ? null
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  notification.message,
                  style: notification.isRead
                      ? null
                      : const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_formatDateTime(notification.createdAt)),
                onTap: notification.isRead
                    ? null
                    : () => _markAsRead(ref, notification),
              );
            },
          );
        },
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyApiError(error,
              fallback: 'Não foi possível carregar as notificações.'),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
      ),
    );
  }
}

Future<void> _markAsRead(WidgetRef ref, NotificationModel notification) async {
  try {
    await ref.read(notificationsRepositoryProvider).markAsRead(notification.id);
    ref.invalidate(notificationsProvider);
  } catch (_) {
    // Falha ao marcar como lida não é crítica — a notificação continua
    // visível e a pessoa pode tentar de novo.
  }
}

String _formatDateTime(DateTime value) {
  final date =
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return '$date às $time';
}
