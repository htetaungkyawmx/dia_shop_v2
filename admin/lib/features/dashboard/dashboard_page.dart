import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/dashboard.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(dashboardProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncSection<Dashboard>(
        value: dashboard,
        onRetry: () => ref.invalidate(dashboardProvider),
        loadingHeight: 480,
        builder: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            await ref.read(dashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (data.pendingOrders > 0 || data.pendingTopups > 0) ...[
                _ActionRequired(data: data),
                const SizedBox(height: 20),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 1250
                      ? 4
                      : constraints.maxWidth > 860
                          ? 3
                          : constraints.maxWidth > 560
                              ? 2
                              : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.75,
                    children: [
                      StatCard(
                        label: 'Revenue today',
                        value: Format.money(data.revenueToday),
                        sublabel: '${data.ordersToday} order(s)',
                        icon: Icons.trending_up_rounded,
                        color: AdminTheme.success,
                      ),
                      StatCard(
                        label: 'Revenue · 30 days',
                        value: Format.money(data.revenue30d),
                        sublabel: 'Profit ${Format.money(data.profit30d)}',
                        icon: Icons.payments_rounded,
                        color: AdminTheme.brand,
                      ),
                      StatCard(
                        label: 'Top-ups · 30 days',
                        value: Format.money(data.topups30d),
                        icon: Icons.account_balance_wallet_rounded,
                        color: AdminTheme.info,
                      ),
                      StatCard(
                        label: 'Wallet liability',
                        value: Format.money(data.walletLiability),
                        sublabel: 'Money customers still hold',
                        icon: Icons.savings_rounded,
                        color: AdminTheme.violet,
                      ),
                      StatCard(
                        label: 'Pending orders',
                        value: '${data.pendingOrders}',
                        icon: Icons.pending_actions_rounded,
                        color: AdminTheme.warning,
                        onTap: () => context.go('/orders'),
                      ),
                      StatCard(
                        label: 'Pending top-ups',
                        value: '${data.pendingTopups}',
                        icon: Icons.receipt_rounded,
                        color: AdminTheme.warning,
                        onTap: () => context.go('/topups'),
                      ),
                      StatCard(
                        label: 'Customers',
                        value: Format.number(data.totalUsers),
                        sublabel: '+${data.newUsers7d} this week',
                        icon: Icons.people_rounded,
                        color: AdminTheme.info,
                        onTap: () => context.go('/users'),
                      ),
                      StatCard(
                        label: 'Open tickets',
                        value: '${data.openTickets}',
                        icon: Icons.support_agent_rounded,
                        color: AdminTheme.danger,
                        onTap: () => context.go('/support'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              PanelCard(
                title: 'Revenue · last 30 days',
                child: SizedBox(height: 240, child: _RevenueChart(points: data.revenueSeries)),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth > 1000;
                  final children = [
                    Expanded(flex: 3, child: _TopSellers(sellers: data.topSellers)),
                    SizedBox(width: side ? 20 : 0, height: side ? 0 : 20),
                    Expanded(flex: 2, child: _LowStock(items: data.lowStock)),
                  ];
                  return side
                      ? IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children))
                      : Column(children: [
                          _TopSellers(sellers: data.topSellers),
                          const SizedBox(height: 20),
                          _LowStock(items: data.lowStock),
                        ]);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRequired extends StatelessWidget {
  const _ActionRequired({required this.data});

  final Dashboard data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AdminTheme.radius),
        border: Border.all(color: AdminTheme.warning.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: AdminTheme.warning),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Waiting on you: ${data.pendingOrders} order(s) and '
              '${data.pendingTopups} top-up(s) need review.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (data.pendingTopups > 0)
            OutlinedButton(
              onPressed: () => context.go('/topups'),
              child: const Text('Review top-ups'),
            ),
          if (data.pendingOrders > 0) ...[
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => context.go('/orders'),
              child: const Text('Review orders'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.points});

  final List<DailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return const AdminEmpty(icon: Icons.show_chart_rounded, title: 'No revenue yet');
    }

    final maxRevenue = points.map((p) => p.revenue).fold<int>(0, (a, b) => a > b ? a : b);
    // Leave headroom above the tallest point so the line never touches the top.
    final maxY = maxRevenue == 0 ? 10000.0 : maxRevenue * 1.25;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: theme.dividerColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Text(
                value >= 1000 ? '${(value / 1000).round()}k' : value.round().toString(),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              // One label a week keeps the axis readable at 30 points.
              interval: 7,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                final parts = points[index].date.split('-');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${parts[2]}/${parts[1]}', style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final point = points[spot.x.round()];
              return LineTooltipItem(
                '${point.date}\n${Format.money(point.revenue)} · ${point.orders} order(s)',
                theme.textTheme.bodySmall!.copyWith(color: Colors.white),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].revenue.toDouble()),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            color: AdminTheme.brand,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AdminTheme.brand.withValues(alpha: 0.28),
                  AdminTheme.brand.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSellers extends StatelessWidget {
  const _TopSellers({required this.sellers});

  final List<TopSeller> sellers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PanelCard(
      title: 'Best sellers · 30 days',
      padding: EdgeInsets.zero,
      child: sellers.isEmpty
          ? const AdminEmpty(icon: Icons.leaderboard_rounded, title: 'No sales yet')
          : Column(
              children: [
                for (final seller in sellers)
                  ListTile(
                    dense: true,
                    title: Text('${seller.productName} · ${seller.variantName}'),
                    subtitle: Text('${seller.quantity} sold'),
                    trailing: Text(
                      Format.money(seller.revenue),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LowStock extends StatelessWidget {
  const _LowStock({required this.items});

  final List<LowStockItem> items;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'Low stock',
      padding: EdgeInsets.zero,
      child: items.isEmpty
          ? const AdminEmpty(
              icon: Icons.inventory_rounded,
              title: 'Everything is stocked',
            )
          : Column(
              children: [
                for (final item in items.take(8))
                  ListTile(
                    dense: true,
                    leading: Icon(
                      item.remaining == 0
                          ? Icons.error_rounded
                          : Icons.warning_amber_rounded,
                      color: item.remaining == 0 ? AdminTheme.danger : AdminTheme.warning,
                      size: 20,
                    ),
                    title: Text(item.variantName),
                    subtitle: Text(item.productName),
                    trailing: StatusBadge(
                      status: item.remaining == 0 ? 'REJECTED' : 'PENDING',
                      label: item.remaining == 0 ? 'Out' : '${item.remaining} left',
                    ),
                    onTap: () => context.go('/products'),
                  ),
              ],
            ),
    );
  }
}
