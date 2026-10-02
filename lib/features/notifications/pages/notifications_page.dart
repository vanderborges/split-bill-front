import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final hasNotifications =
        notificationsAsync.valueOrNull?.isNotEmpty ?? false;

    return AppScaffold(
      title: 'Notificações',
      actions: [
        if (hasNotifications)
          IconButton(
            tooltip: 'Limpar todas',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmClearAll(context, ref),
          ),
      ],
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
              return Dismissible(
                key: ValueKey(notification.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) => _delete(ref, notification),
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                child: ListTile(
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
                  trailing: notification.pixKey == null
                      ? null
                      : IconButton(
                          tooltip:
                              'Copiar PIX de ${notification.receiverName}',
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () => _copyPixKey(context, notification),
                        ),
                  onTap: notification.isRead
                      ? null
                      : () => _markAsRead(ref, notification),
                ),
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

Future<bool> _confirmDelete(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remover notificação'),
      content: const Text('Deseja remover esta notificação?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover')),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<void> _delete(WidgetRef ref, NotificationModel notification) async {
  try {
    await ref.read(notificationsRepositoryProvider).delete(notification.id);
  } finally {
    // Mesmo se a chamada falhar, invalida pra refletir o estado real do
    // servidor (o Dismissible já tirou o item da tela otimisticamente).
    ref.invalidate(notificationsProvider);
  }
}

Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Limpar notificações'),
      content: const Text(
          'Remove todas as notificações desta conta. Essa ação não pode ser desfeita.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpar tudo')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  try {
    await ref.read(notificationsRepositoryProvider).clearAll();
    ref.invalidate(notificationsProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyApiError(error,
                fallback: 'Não foi possível limpar as notificações.'))),
      );
    }
  }
}

Future<void> _copyPixKey(
    BuildContext context, NotificationModel notification) async {
  final pixKey = notification.pixKey;
  if (pixKey == null) {
    return;
  }
  await Clipboard.setData(ClipboardData(text: pixKey));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Chave PIX de ${notification.receiverName ?? "destinatário"} copiada.')),
    );
  }
}

String _formatDateTime(DateTime value) {
  final date =
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return '$date às $time';
}
