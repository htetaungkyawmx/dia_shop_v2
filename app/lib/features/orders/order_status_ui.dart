import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';

/// Single source of truth for how each order status looks and reads.
class OrderStatusUi {
  const OrderStatusUi._();

  static String label(OrderStatus status, Strings strings) => switch (status) {
        OrderStatus.pending => strings.statusPending,
        OrderStatus.processing => strings.statusProcessing,
        OrderStatus.completed => strings.statusCompleted,
        OrderStatus.rejected => strings.statusRejected,
        OrderStatus.cancelled => strings.statusCancelled,
        OrderStatus.refunded => strings.statusRefunded,
      };

  static Color color(OrderStatus status) => switch (status) {
        OrderStatus.pending => AppTheme.warning,
        OrderStatus.processing => AppTheme.info,
        OrderStatus.completed => AppTheme.success,
        OrderStatus.rejected => AppTheme.danger,
        OrderStatus.cancelled => AppTheme.danger,
        OrderStatus.refunded => AppTheme.brand,
      };

  static IconData icon(OrderStatus status) => switch (status) {
        OrderStatus.pending => Icons.hourglass_empty_rounded,
        OrderStatus.processing => Icons.autorenew_rounded,
        OrderStatus.completed => Icons.check_circle_rounded,
        OrderStatus.rejected => Icons.cancel_rounded,
        OrderStatus.cancelled => Icons.remove_circle_rounded,
        OrderStatus.refunded => Icons.replay_rounded,
      };
}
