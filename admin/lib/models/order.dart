enum OrderStatus {
  pending,
  processing,
  completed,
  rejected,
  cancelled,
  refunded;

  static OrderStatus parse(String? raw) => switch (raw) {
        'PROCESSING' => OrderStatus.processing,
        'COMPLETED' => OrderStatus.completed,
        'REJECTED' => OrderStatus.rejected,
        'CANCELLED' => OrderStatus.cancelled,
        'REFUNDED' => OrderStatus.refunded,
        _ => OrderStatus.pending,
      };

  String get wireValue => switch (this) {
        OrderStatus.pending => 'PENDING',
        OrderStatus.processing => 'PROCESSING',
        OrderStatus.completed => 'COMPLETED',
        OrderStatus.rejected => 'REJECTED',
        OrderStatus.cancelled => 'CANCELLED',
        OrderStatus.refunded => 'REFUNDED',
      };

  bool get isOpen => this == OrderStatus.pending || this == OrderStatus.processing;

  bool get canCancel => this == OrderStatus.pending;
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.imageUrl,
    this.fieldValues = const {},
    this.deliveredCode,
    this.deliveredSecret,
  });

  final int id;
  final int variantId;
  final String productName;
  final String variantName;
  final int unitPrice;
  final int quantity;
  final int lineTotal;
  final String? imageUrl;
  final Map<String, String> fieldValues;
  final String? deliveredCode;
  final String? deliveredSecret;

  bool get hasCode => (deliveredCode ?? '').isNotEmpty;

  List<String> get codes => (deliveredCode ?? '').split('\n').where((c) => c.isNotEmpty).toList();

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: (json['id'] as num).toInt(),
        variantId: (json['variantId'] as num).toInt(),
        productName: json['productName'] as String,
        variantName: json['variantName'] as String,
        unitPrice: (json['unitPrice'] as num).toInt(),
        quantity: (json['quantity'] as num).toInt(),
        lineTotal: (json['lineTotal'] as num).toInt(),
        imageUrl: json['imageUrl'] as String?,
        fieldValues: (json['fieldValues'] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, '$value')),
        deliveredCode: json['deliveredCode'] as String?,
        deliveredSecret: json['deliveredSecret'] as String?,
      );
}

class Order {
  const Order({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.subtotal,
    required this.total,
    required this.items,
    required this.createdAt,
    this.customerNote,
    this.adminNote,
    this.rejectReason,
    this.processedAt,
    this.userEmail,
    this.userName,
  });

  final int id;
  final String orderNo;
  final OrderStatus status;
  final int subtotal;
  final int total;
  final List<OrderItem> items;
  final DateTime createdAt;
  final String? customerNote;
  final String? adminNote;
  final String? rejectReason;
  final DateTime? processedAt;
  final String? userEmail;
  final String? userName;

  String get title => items.isEmpty
      ? orderNo
      : items.length == 1
          ? '${items.first.productName} · ${items.first.variantName}'
          : '${items.first.productName} +${items.length - 1} more';

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: (json['id'] as num).toInt(),
        orderNo: json['orderNo'] as String,
        status: OrderStatus.parse(json['status'] as String?),
        subtotal: (json['subtotal'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        customerNote: json['customerNote'] as String?,
        adminNote: json['adminNote'] as String?,
        rejectReason: json['rejectReason'] as String?,
        processedAt:
            json['processedAt'] == null ? null : DateTime.parse(json['processedAt'] as String),
        userEmail: json['userEmail'] as String?,
        userName: json['userName'] as String?,
      );
}

class OrderQuoteLine {
  const OrderQuoteLine({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.available,
    this.unavailableReason,
  });

  final int variantId;
  final String productName;
  final String variantName;
  final int unitPrice;
  final int quantity;
  final int lineTotal;
  final bool available;
  final String? unavailableReason;

  factory OrderQuoteLine.fromJson(Map<String, dynamic> json) => OrderQuoteLine(
        variantId: (json['variantId'] as num).toInt(),
        productName: json['productName'] as String,
        variantName: json['variantName'] as String,
        unitPrice: (json['unitPrice'] as num).toInt(),
        quantity: (json['quantity'] as num).toInt(),
        lineTotal: (json['lineTotal'] as num).toInt(),
        available: json['available'] as bool? ?? false,
        unavailableReason: json['unavailableReason'] as String?,
      );
}

class OrderQuote {
  const OrderQuote({
    required this.subtotal,
    required this.total,
    required this.walletBalance,
    required this.balanceAfter,
    required this.affordable,
    required this.lines,
  });

  final int subtotal;
  final int total;
  final int walletBalance;
  final int balanceAfter;
  final bool affordable;
  final List<OrderQuoteLine> lines;

  int get shortfall => balanceAfter < 0 ? -balanceAfter : 0;

  factory OrderQuote.fromJson(Map<String, dynamic> json) => OrderQuote(
        subtotal: (json['subtotal'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        walletBalance: (json['walletBalance'] as num).toInt(),
        balanceAfter: (json['balanceAfter'] as num).toInt(),
        affordable: json['affordable'] as bool? ?? false,
        lines: (json['lines'] as List<dynamic>? ?? [])
            .map((e) => OrderQuoteLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One line in the basket before checkout.
class CartLine {
  CartLine({
    required this.product,
    required this.variantId,
    required this.variantName,
    required this.unitPrice,
    required this.quantity,
    required this.fieldValues,
    this.imageUrl,
  });

  final String product;
  final int variantId;
  final String variantName;
  final int unitPrice;
  final int quantity;
  final Map<String, String> fieldValues;
  final String? imageUrl;

  int get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toRequestJson() => {
        'variantId': variantId,
        'quantity': quantity,
        'fieldValues': fieldValues,
      };
}
