import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'order_status_ui.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final int orderId;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final strings = Strings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.cancelOrder),
        content: Text(strings.cancelOrderConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings.close)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(orderRepositoryProvider).cancel(orderId);
      ref.invalidate(orderProvider(orderId));
      ref.invalidate(ordersProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(walletTransactionsProvider);
      if (context.mounted) AppSnack.success(context, strings.statusCancelled);
    } catch (error) {
      if (context.mounted) AppSnack.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: Text(strings.orderNumber)),
      body: MaxWidthBody(
        child: order.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              ShimmerBox(height: 120, radius: AppTheme.radius),
              SizedBox(height: 12),
              ShimmerBox(height: 180, radius: AppTheme.radius),
            ],
          ),
          error: (error, _) =>
              ErrorView(error: error, onRetry: () => ref.invalidate(orderProvider(orderId))),
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderProvider(orderId));
              await ref.read(orderProvider(orderId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusHeader(order: data),
                const SizedBox(height: 14),
                for (final item in data.items) ...[
                  _ItemCard(item: item),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _InfoRow(label: strings.orderNumber, value: data.orderNo, copyable: true),
                        const SizedBox(height: 10),
                        _InfoRow(label: strings.orderDate, value: Format.dateTime(data.createdAt)),
                        const SizedBox(height: 10),
                        _InfoRow(label: strings.subtotal, value: Format.money(data.subtotal)),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(),
                        ),
                        _InfoRow(
                          label: strings.total,
                          value: Format.money(data.total),
                          emphasise: true,
                        ),
                      ],
                    ),
                  ),
                ),
                if ((data.customerNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _NoteCard(
                    title: strings.noteToSeller,
                    body: data.customerNote!,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
                if ((data.rejectReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _NoteCard(
                    title: strings.rejectedReason,
                    body: data.rejectReason!,
                    color: AppTheme.danger,
                  ),
                ],
                if ((data.adminNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _NoteCard(
                    title: strings.adminNote,
                    body: data.adminNote!,
                    color: AppTheme.info,
                  ),
                ],
                if (data.status.canCancel) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _cancel(context, ref),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(strings.cancelOrder),
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final color = OrderStatusUi.color(order.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(OrderStatusUi.icon(order.status), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  OrderStatusUi.label(order.status, strings),
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  order.processedAt != null
                      ? Format.dateTime(order.processedAt!)
                      : Format.relative(order.createdAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppImage(
                  url: item.imageUrl,
                  width: 52,
                  height: 52,
                  fallbackIcon: Icons.sports_esports_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: theme.textTheme.titleSmall),
                      Text(
                        '${item.variantName} × ${item.quantity}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  Format.money(item.lineTotal),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (item.fieldValues.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 10),
              for (final entry in item.fieldValues.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _InfoRow(label: _label(entry.key), value: entry.value, copyable: true),
                ),
            ],
            if (item.hasCode) ...[
              const SizedBox(height: 12),
              Text(strings.yourCode, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final code in item.codes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            code,
                            style: theme.textTheme.titleSmall?.copyWith(letterSpacing: 0.6),
                          ),
                        ),
                        IconButton(
                          tooltip: strings.copy,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (context.mounted) AppSnack.success(context, strings.copied);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (item.deliveredSecret != null)
                Text('PIN: ${item.deliveredSecret}', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  static String _label(String key) => key
      .split('_')
      .map((part) => part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool copyable;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: (emphasise ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (copyable)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: strings.copy,
            icon: const Icon(Icons.copy_rounded, size: 15),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) AppSnack.success(context, strings.copied);
            },
          ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.title, required this.body, required this.color});

  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
