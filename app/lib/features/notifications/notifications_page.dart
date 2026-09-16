import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../models/misc.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(miscRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: Text(strings.markAllRead),
          ),
        ],
      ),
      body: MaxWidthBody(
        child: notifications.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, __) => const ShimmerBox(height: 80),
          ),
          error: (error, _) =>
              ErrorView(error: error, onRetry: () => ref.invalidate(notificationsProvider)),
          data: (page) {
            if (page.items.isEmpty) {
              return EmptyView(
                icon: Icons.notifications_none_rounded,
                title: strings.noNotifications,
                message: strings.noNotificationsBody,
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsProvider);
                await ref.read(notificationsProvider.future);
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: page.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _NotificationCard(notification: page.items[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  /// Opens whatever the notification points at, based on its data payload.
  void _open(BuildContext context) {
    final screen = notification.data['screen'];
    final orderId = notification.data['orderId'];
    if (screen == 'order' && orderId != null) {
      context.push('/orders/$orderId');
    } else if (screen == 'wallet') {
      context.push('/wallet');
    } else if (screen == 'support') {
      context.push('/support');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = switch (notification.type) {
      'ORDER' => AppTheme.info,
      'TOPUP' => AppTheme.success,
      'PROMOTION' => AppTheme.gold,
      'SYSTEM' => AppTheme.brand,
      _ => AppTheme.brand,
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () async {
          if (!notification.read && !notification.broadcast) {
            await ref.read(miscRepositoryProvider).markRead(notification.id);
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadCountProvider);
          }
          if (context.mounted) _open(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(
                  switch (notification.type) {
                    'ORDER' => Icons.receipt_long_rounded,
                    'TOPUP' => Icons.account_balance_wallet_rounded,
                    'PROMOTION' => Icons.local_offer_rounded,
                    _ => Icons.campaign_rounded,
                  },
                  size: 19,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight:
                                  notification.read ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.read && !notification.broadcast)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(notification.body, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Text(
                      Format.relative(notification.createdAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
