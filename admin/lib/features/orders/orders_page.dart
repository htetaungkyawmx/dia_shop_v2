import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  OrderFilter _filter = const OrderFilter(status: OrderStatus.pending);
  Order? _selected;

  void _refresh() {
    ref.invalidate(ordersProvider);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider(_filter));
    final wide = MediaQuery.sizeOf(context).width >= 1150;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          SearchField(
            hint: 'Order no, email or name',
            onChanged: (value) => setState(() =>
                _filter = OrderFilter(status: _filter.status, query: value)),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Wrap(
              spacing: 8,
              children: [
                _statusChip(null, 'All'),
                for (final status in OrderStatus.values)
                  _statusChip(status, prettyStatus(status.wireValue)),
              ],
            ),
          ),
          Expanded(
            child: AsyncSection(
              value: orders,
              onRetry: _refresh,
              loadingHeight: 420,
              builder: (page) {
                if (page.items.isEmpty) {
                  return const AdminEmpty(
                    icon: Icons.receipt_long_rounded,
                    title: 'No orders here',
                    message: 'Try a different status filter.',
                  );
                }
                final list = ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = page.items[index];
                    return _OrderRow(
                      order: order,
                      selected: _selected?.id == order.id,
                      onTap: () => wide
                          ? setState(() => _selected = order)
                          : _openSheet(context, order),
                    );
                  },
                );

                if (!wide) return list;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: _selected == null
                          ? const AdminEmpty(
                              icon: Icons.touch_app_rounded,
                              title: 'Select an order',
                              message:
                                  'Pick an order on the left to review and act on it.',
                            )
                          : OrderDetailPanel(
                              orderId: _selected!.id,
                              onChanged: (order) {
                                setState(() => _selected = order);
                                _refresh();
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(OrderStatus? status, String label) {
    final selected = _filter.status == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(
          () => _filter = OrderFilter(status: status, query: _filter.query)),
    );
  }

  void _openSheet(BuildContext context, Order order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: OrderDetailPanel(
          orderId: order.id,
          onChanged: (_) => _refresh(),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow(
      {required this.order, required this.selected, required this.onTap});

  final Order order;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminTheme.radius),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.dividerColor,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNo, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      order.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.userName ?? '—',
                        style: theme.textTheme.bodyMedium),
                    Text(
                      order.userEmail ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  Format.money(order.total),
                  style: theme.textTheme.titleSmall,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                  width: 108,
                  child: StatusBadge(status: order.status.wireValue)),
              SizedBox(
                width: 88,
                child: Text(
                  Format.relative(order.createdAt),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail + actions for one order. Used inline on wide screens and in a sheet
/// on narrow ones, so there is only one implementation of the workflow.
class OrderDetailPanel extends ConsumerStatefulWidget {
  const OrderDetailPanel(
      {super.key, required this.orderId, required this.onChanged});

  final int orderId;
  final ValueChanged<Order> onChanged;

  @override
  ConsumerState<OrderDetailPanel> createState() => _OrderDetailPanelState();
}

class _OrderDetailPanelState extends ConsumerState<OrderDetailPanel> {
  bool _busy = false;

  Future<void> _run(Future<Order> Function() action) async {
    setState(() => _busy = true);
    try {
      final order = await action();
      ref.invalidate(orderProvider(widget.orderId));
      widget.onChanged(order);
      if (mounted) {
        AdminSnack.success(
            context, 'Order ${order.orderNo} is now ${order.status.wireValue}');
      }
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = ref.watch(orderProvider(widget.orderId));
    final api = ref.read(apiProvider);

    return AsyncSection(
      value: order,
      onRetry: () => ref.invalidate(orderProvider(widget.orderId)),
      loadingHeight: 400,
      builder: (data) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.orderNo, style: theme.textTheme.titleLarge),
                          Text(
                            Format.dateTime(data.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: data.status.wireValue),
                  ],
                ),
                const SizedBox(height: 20),
                PanelCard(
                  title: 'Customer',
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.userName ?? '—',
                          style: theme.textTheme.titleSmall),
                      Text(data.userEmail ?? '',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PanelCard(
                  title: 'Items',
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    children: [
                      for (final item in data.items) ...[
                        _ItemBlock(item: item),
                        if (item != data.items.last) const Divider(height: 24),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: theme.textTheme.titleSmall),
                          Text(Format.money(data.total),
                              style: theme.textTheme.titleMedium),
                        ],
                      ),
                    ],
                  ),
                ),
                if ((data.customerNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  PanelCard(
                    title: 'Customer note',
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Text(data.customerNote!),
                  ),
                ],
                if ((data.adminNote ?? '').isNotEmpty ||
                    (data.rejectReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  PanelCard(
                    title: 'Staff note',
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((data.rejectReason ?? '').isNotEmpty)
                          Text('Reason: ${data.rejectReason}'),
                        if ((data.adminNote ?? '').isNotEmpty)
                          Text(data.adminNote!),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (!data.status.isOpen && data.status != OrderStatus.completed)
            const SizedBox.shrink()
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: _busy
                  ? const Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        if (data.status == OrderStatus.pending)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _run(() => api.processOrder(data.id)),
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Start'),
                          ),
                        if (data.status.isOpen)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final reason = await promptForNote(
                                context,
                                title: 'Reject order',
                                message:
                                    '${Format.money(data.total)} goes straight back to the '
                                    'customer wallet and any reserved stock is released.',
                                confirmLabel: 'Reject and refund',
                                noteLabel: 'Reason shown to the customer',
                                noteRequired: true,
                                confirmColor: AdminTheme.danger,
                              );
                              if (reason == null) return;
                              await _run(
                                  () => api.rejectOrder(data.id, reason, null));
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AdminTheme.danger),
                          ),
                        if (data.status == OrderStatus.completed)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final note = await promptForNote(
                                context,
                                title: 'Refund order',
                                message:
                                    'Return ${Format.money(data.total)} to the customer wallet?',
                                confirmLabel: 'Refund',
                                confirmColor: AdminTheme.violet,
                              );
                              if (note == null) return;
                              await _run(() => api.refundOrder(data.id, note));
                            },
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: const Text('Refund'),
                          ),
                        if (data.status.isOpen)
                          FilledButton.icon(
                            onPressed: () async {
                              final note = await promptForNote(
                                context,
                                title: 'Mark delivered',
                                message:
                                    'Confirm the customer has received this order.',
                                confirmLabel: 'Mark delivered',
                                confirmColor: AdminTheme.success,
                              );
                              if (note == null) return;
                              await _run(
                                  () => api.completeOrder(data.id, note));
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Mark delivered'),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _ItemBlock extends StatelessWidget {
  const _ItemBlock({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${item.productName} · ${item.variantName} × ${item.quantity}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(Format.money(item.lineTotal),
                style: theme.textTheme.bodyMedium),
          ],
        ),
        if (item.fieldValues.isNotEmpty) ...[
          const SizedBox(height: 10),
          // The fulfilment details staff actually need to type into the game
          // panel — one tap copies each value.
          for (final entry in item.fieldValues.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      entry.key,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(entry.value,
                        style: theme.textTheme.titleSmall),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: entry.value));
                      if (context.mounted) {
                        AdminSnack.success(context, 'Copied');
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
        if (item.hasCode) ...[
          const SizedBox(height: 8),
          Text('Delivered codes', style: theme.textTheme.labelLarge),
          for (final code in item.codes)
            SelectableText(code, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}
