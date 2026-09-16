class Wallet {
  const Wallet({required this.balance, required this.pendingTopupAmount});

  final int balance;
  final int pendingTopupAmount;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        pendingTopupAmount: (json['pendingTopupAmount'] as num?)?.toInt() ?? 0,
      );
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String type;
  final int amount;
  final int balanceAfter;
  final String description;
  final DateTime createdAt;

  bool get isCredit => amount > 0;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toInt(),
        balanceAfter: (json['balanceAfter'] as num).toInt(),
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.code,
    required this.name,
    required this.accountName,
    required this.accountNumber,
    required this.minAmount,
    required this.maxAmount,
    this.logoUrl,
    this.instructions,
    this.instructionsMy,
  });

  final int id;
  final String code;
  final String name;
  final String accountName;
  final String accountNumber;
  final int minAmount;
  final int maxAmount;
  final String? logoUrl;
  final String? instructions;
  final String? instructionsMy;

  String? localisedInstructions(bool burmese) =>
      burmese && (instructionsMy?.isNotEmpty ?? false)
          ? instructionsMy
          : instructions;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: (json['id'] as num).toInt(),
        code: json['code'] as String,
        name: json['name'] as String,
        accountName: json['accountName'] as String,
        accountNumber: json['accountNumber'] as String,
        minAmount: (json['minAmount'] as num?)?.toInt() ?? 1000,
        maxAmount: (json['maxAmount'] as num?)?.toInt() ?? 5000000,
        logoUrl: json['logoUrl'] as String?,
        instructions: json['instructions'] as String?,
        instructionsMy: json['instructionsMy'] as String?,
      );
}

enum TopupStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static TopupStatus parse(String? raw) => switch (raw) {
        'APPROVED' => TopupStatus.approved,
        'REJECTED' => TopupStatus.rejected,
        'CANCELLED' => TopupStatus.cancelled,
        _ => TopupStatus.pending,
      };
}

class TopupRequest {
  const TopupRequest({
    required this.id,
    required this.requestNo,
    required this.amount,
    required this.status,
    required this.paymentMethodName,
    required this.referenceNo,
    required this.createdAt,
    this.screenshotUrl,
    this.adminNote,
    this.reviewedAt,
    this.userEmail,
    this.userName,
    this.senderName,
    this.senderPhone,
  });

  final int id;
  final String requestNo;
  final int amount;
  final TopupStatus status;
  final String paymentMethodName;
  final String referenceNo;
  final DateTime createdAt;
  final String? screenshotUrl;
  final String? adminNote;
  final DateTime? reviewedAt;
  final String? userEmail;
  final String? userName;
  final String? senderName;
  final String? senderPhone;

  factory TopupRequest.fromJson(Map<String, dynamic> json) => TopupRequest(
        id: (json['id'] as num).toInt(),
        requestNo: json['requestNo'] as String,
        amount: (json['amount'] as num).toInt(),
        status: TopupStatus.parse(json['status'] as String?),
        paymentMethodName: json['paymentMethodName'] as String? ?? '',
        referenceNo: json['referenceNo'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        screenshotUrl: json['screenshotUrl'] as String?,
        adminNote: json['adminNote'] as String?,
        reviewedAt: json['reviewedAt'] == null
            ? null
            : DateTime.parse(json['reviewedAt'] as String),
        userEmail: json['userEmail'] as String?,
        userName: json['userName'] as String?,
        senderName: json['senderName'] as String?,
        senderPhone: json['senderPhone'] as String?,
      );
}
