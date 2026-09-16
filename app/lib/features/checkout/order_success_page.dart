import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class OrderSuccessPage extends ConsumerWidget {
  const OrderSuccessPage({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final theme = Theme.of(context);
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      body: SafeArea(
        child: MaxWidthBody(
          maxWidth: 520,
          child: order.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(error: error),
            data: (data) {
              final delivered = data.status == OrderStatus.completed;
              final codes = data.items.where((i) => i.hasCode).toList();

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: (delivered ? AppTheme.success : AppTheme.info)
                            .withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        delivered ? Icons.check_rounded : Icons.hourglass_top_rounded,
                        size: 44,
                        color: delivered ? AppTheme.success : AppTheme.info,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    delivered ? strings.orderDelivered : strings.orderPlaced,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    delivered ? strings.orderDeliveredBody : strings.orderPlacedBody,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      title: Text(strings.orderNumber),
                      subtitle: Text(
                        data.orderNo,
                        style: theme.textTheme.titleMedium,
                      ),
                      trailing: IconButton(
                        tooltip: strings.copy,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: data.orderNo));
                          if (context.mounted) AppSnack.success(context, strings.copied);
                        },
                      ),
                    ),
                  ),
                  if (codes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    for (final item in codes) _CodeCard(item: item),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => context.pushReplacement('/orders/${data.id}'),
                    child: Text(strings.viewOrder),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => context.go('/shop'),
                    child: Text(strings.keepShopping),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.productName} · ${item.variantName}',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final code in item.codes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          code,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            letterSpacing: 0.6,
                          ),
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
        ),
      ),
    );
  }
}
