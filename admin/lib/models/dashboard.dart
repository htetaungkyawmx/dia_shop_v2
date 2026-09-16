class DailyPoint {
  const DailyPoint({required this.date, required this.orders, required this.revenue});

  final String date;
  final int orders;
  final int revenue;

  factory DailyPoint.fromJson(Map<String, dynamic> json) => DailyPoint(
        date: json['date'] as String,
        orders: (json['orders'] as num?)?.toInt() ?? 0,
        revenue: (json['revenue'] as num?)?.toInt() ?? 0,
      );
}

class TopSeller {
  const TopSeller({
    required this.productName,
    required this.variantName,
    required this.quantity,
    required this.revenue,
  });

  final String productName;
  final String variantName;
  final int quantity;
  final int revenue;

  factory TopSeller.fromJson(Map<String, dynamic> json) => TopSeller(
        productName: json['productName'] as String? ?? '',
        variantName: json['variantName'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        revenue: (json['revenue'] as num?)?.toInt() ?? 0,
      );
}

class LowStockItem {
  const LowStockItem({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.remaining,
    required this.threshold,
    required this.stockType,
  });

  final int variantId;
  final String productName;
  final String variantName;
  final int remaining;
  final int threshold;
  final String stockType;

  factory LowStockItem.fromJson(Map<String, dynamic> json) => LowStockItem(
        variantId: (json['variantId'] as num).toInt(),
        productName: json['productName'] as String? ?? '',
        variantName: json['variantName'] as String? ?? '',
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
        threshold: (json['threshold'] as num?)?.toInt() ?? 0,
        stockType: json['stockType'] as String? ?? 'LIMITED',
      );
}

class Dashboard {
  const Dashboard({
    required this.pendingOrders,
    required this.pendingTopups,
    required this.openTickets,
    required this.totalUsers,
    required this.activeUsers,
    required this.newUsers7d,
    required this.revenueToday,
    required this.revenue7d,
    required this.revenue30d,
    required this.profit30d,
    required this.ordersToday,
    required this.orders30d,
    required this.topups30d,
    required this.walletLiability,
    required this.revenueSeries,
    required this.topSellers,
    required this.lowStock,
  });

  final int pendingOrders;
  final int pendingTopups;
  final int openTickets;
  final int totalUsers;
  final int activeUsers;
  final int newUsers7d;
  final int revenueToday;
  final int revenue7d;
  final int revenue30d;
  final int profit30d;
  final int ordersToday;
  final int orders30d;
  final int topups30d;
  final int walletLiability;
  final List<DailyPoint> revenueSeries;
  final List<TopSeller> topSellers;
  final List<LowStockItem> lowStock;

  /// All-zero placeholder used while signed out, so the shell can render its
  /// badges without an admin request ever leaving the browser.
  static const empty = Dashboard(
    pendingOrders: 0,
    pendingTopups: 0,
    openTickets: 0,
    totalUsers: 0,
    activeUsers: 0,
    newUsers7d: 0,
    revenueToday: 0,
    revenue7d: 0,
    revenue30d: 0,
    profit30d: 0,
    ordersToday: 0,
    orders30d: 0,
    topups30d: 0,
    walletLiability: 0,
    revenueSeries: [],
    topSellers: [],
    lowStock: [],
  );

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return Dashboard(
      pendingOrders: read('pendingOrders'),
      pendingTopups: read('pendingTopups'),
      openTickets: read('openTickets'),
      totalUsers: read('totalUsers'),
      activeUsers: read('activeUsers'),
      newUsers7d: read('newUsers7d'),
      revenueToday: read('revenueToday'),
      revenue7d: read('revenue7d'),
      revenue30d: read('revenue30d'),
      profit30d: read('profit30d'),
      ordersToday: read('ordersToday'),
      orders30d: read('orders30d'),
      topups30d: read('topups30d'),
      walletLiability: read('walletLiability'),
      revenueSeries: (json['revenueSeries'] as List<dynamic>? ?? [])
          .map((e) => DailyPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      topSellers: (json['topSellers'] as List<dynamic>? ?? [])
          .map((e) => TopSeller.fromJson(e as Map<String, dynamic>))
          .toList(),
      lowStock: (json['lowStock'] as List<dynamic>? ?? [])
          .map((e) => LowStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
