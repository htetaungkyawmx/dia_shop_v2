import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/common.dart';
import 'order_status_ui.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final orders = ref.watch(ordersProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: Text(strings.myOrders)),
      body: MaxWidthBody(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  CategoryPill(
                    label: strings.allOrders,
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final status in [
                    OrderStatus.pending,
                    OrderStatus.processing,
                    OrderStatus.completed,
                    OrderStatus.rejected,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: CategoryPill(
                        label: OrderStatusUi.label(status, strings),
                        selected: _filter == status,
                        onTap: () => setState(() => _filter = status),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: orders.when(
                loading: () => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, __) => const ShimmerBox(height: 92),
                ),
                error: (error, _) =>
                    ErrorView(error: error, onRetry: () => ref.invalidate(ordersProvider(_filter))),
                data: (page) {
                  if (page.items.isEmpty) {
                    return EmptyView(
                      icon: Icons.receipt_long_outlined,
                      title: strings.noOrders,
                      message: strings.noOrdersBody,
                      action: FilledButton(
                        onPressed: () => context.go('/shop'),
                        child: Text(strings.keepShopping),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(ordersProvider(_filter));
                      await ref.read(ordersProvider(_filter).future);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: page.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _OrderCard(order: page.items[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Card(
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AppImage(
                url: order.items.isEmpty ? null : order.items.first.imageUrl,
                width: 52,
                height: 52,
                fallbackIcon: Icons.receipt_long_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.orderNo} · ${Format.relative(order.createdAt)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    StatusChip(
                      label: OrderStatusUi.label(order.status, strings),
                      color: OrderStatusUi.color(order.status),
                      icon: OrderStatusUi.icon(order.status),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Format.money(order.total),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
