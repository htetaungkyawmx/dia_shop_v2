class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.broadcast,
    required this.createdAt,
    this.data = const {},
  });

  final int id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final bool broadcast;
  final DateTime createdAt;
  final Map<String, String> data;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        body: json['body'] as String,
        type: json['type'] as String? ?? 'GENERAL',
        read: json['read'] as bool? ?? false,
        broadcast: json['broadcast'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        data: (json['data'] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, '$value')),
      );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.adminReply,
    this.repliedAt,
    this.orderNo,
    this.userEmail,
    this.userName,
  });

  final int id;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;
  final String? adminReply;
  final DateTime? repliedAt;
  final String? orderNo;
  final String? userEmail;
  final String? userName;

  bool get answered => (adminReply ?? '').isNotEmpty;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: (json['id'] as num).toInt(),
        subject: json['subject'] as String,
        message: json['message'] as String,
        status: json['status'] as String? ?? 'OPEN',
        createdAt: DateTime.parse(json['createdAt'] as String),
        adminReply: json['adminReply'] as String?,
        repliedAt: json['repliedAt'] == null
            ? null
            : DateTime.parse(json['repliedAt'] as String),
        orderNo: json['orderNo'] as String?,
        userEmail: json['userEmail'] as String?,
        userName: json['userName'] as String?,
      );
}

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.maintenance,
    required this.maintenanceMessage,
    required this.topupMinAmount,
    required this.topupMaxAmount,
    required this.support,
  });

  final String appName;
  final bool maintenance;
  final String maintenanceMessage;
  final int topupMinAmount;
  final int topupMaxAmount;
  final Map<String, String> support;

  static const fallback = AppConfig(
    appName: 'SSHGameShop',
    maintenance: false,
    maintenanceMessage: '',
    topupMinAmount: 1000,
    topupMaxAmount: 5000000,
    support: {},
  );

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        appName: json['appName'] as String? ?? 'SSHGameShop',
        maintenance: json['maintenance'] as bool? ?? false,
        maintenanceMessage: json['maintenanceMessage'] as String? ?? '',
        topupMinAmount: (json['topupMinAmount'] as num?)?.toInt() ?? 1000,
        topupMaxAmount: (json['topupMaxAmount'] as num?)?.toInt() ?? 5000000,
        support: (json['support'] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, '$value')),
      );
}

/// Envelope returned by every paged endpoint.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
  });

  final List<T> items;
  final int page;
  final int totalItems;
  final int totalPages;
  final bool hasNext;

  static Paged<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    return Paged<T>(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => parse(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }

  static Paged<T> empty<T>() => Paged<T>(
      items: const [], page: 0, totalItems: 0, totalPages: 0, hasNext: false);
}
