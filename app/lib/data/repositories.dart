import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/catalog.dart';
import '../models/misc.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../models/wallet.dart';

/// Result of a successful sign-in: the tokens plus the freshly loaded profile.
class AuthResult {
  const AuthResult({required this.accessToken, required this.refreshToken, required this.user});

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      auth: false,
      body: {
        'email': email,
        'password': password,
        'displayName': displayName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> login({required String email, required String password, String? deviceInfo}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      auth: false,
      body: {'email': email, 'password': password, if (deviceInfo != null) 'deviceInfo': deviceInfo},
    );
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> loginWithGoogle(String idToken, {String? deviceInfo}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/google',
      auth: false,
      body: {'idToken': idToken, if (deviceInfo != null) 'deviceInfo': deviceInfo},
    );
    return AuthResult.fromJson(json);
  }

  Future<void> logout(String? refreshToken) async {
    await _api.post<dynamic>('/auth/logout', body: {'refreshToken': refreshToken ?? ''});
  }

  Future<AppUser> me() async {
    final json = await _api.get<Map<String, dynamic>>('/me');
    return AppUser.fromJson(json);
  }

  Future<AppUser> updateProfile({
    String? displayName,
    String? phone,
    String? photoUrl,
    String? locale,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>('/me', body: {
      if (displayName != null) 'displayName': displayName,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (locale != null) 'locale': locale,
    });
    return AppUser.fromJson(json);
  }

  Future<void> changePassword({required String current, required String next}) async {
    await _api.post<dynamic>('/me/password', body: {
      'currentPassword': current,
      'newPassword': next,
    });
  }

  Future<void> registerDevice(String fcmToken, String platform) async {
    await _api.post<dynamic>('/me/devices', body: {'fcmToken': fcmToken, 'platform': platform});
  }
}

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<AppConfig> config() async {
    final json = await _api.get<Map<String, dynamic>>('/public/config', auth: false);
    return AppConfig.fromJson(json);
  }

  Future<HomeData> home() async {
    final json = await _api.get<Map<String, dynamic>>('/public/home', auth: false);
    return HomeData.fromJson(json);
  }

  Future<List<Category>> categories() async {
    final json = await _api.get<List<dynamic>>('/public/categories', auth: false);
    return json.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ProductSummary>> products({String? category, String? query}) async {
    final json = await _api.get<List<dynamic>>(
      '/public/products',
      auth: false,
      query: {'category': category, 'q': query},
    );
    return json.map((e) => ProductSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProductDetail> product(String slug) async {
    final json = await _api.get<Map<String, dynamic>>('/public/products/$slug', auth: false);
    return ProductDetail.fromJson(json);
  }
}

class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  Future<OrderQuote> quote(List<CartLine> lines) async {
    final json = await _api.post<Map<String, dynamic>>('/orders/quote', body: {
      'items': lines.map((l) => l.toRequestJson()).toList(),
    });
    return OrderQuote.fromJson(json);
  }

  Future<Order> create(List<CartLine> lines, {String? note}) async {
    final json = await _api.post<Map<String, dynamic>>('/orders', body: {
      'items': lines.map((l) => l.toRequestJson()).toList(),
      if (note != null && note.isNotEmpty) 'customerNote': note,
    });
    return Order.fromJson(json);
  }

  Future<Paged<Order>> list({OrderStatus? status, int page = 0, int size = 20}) async {
    final json = await _api.get<Map<String, dynamic>>('/orders', query: {
      'status': status?.wireValue,
      'page': page,
      'size': size,
    });
    return Paged.fromJson(json, Order.fromJson);
  }

  Future<Order> get(int id) async {
    final json = await _api.get<Map<String, dynamic>>('/orders/$id');
    return Order.fromJson(json);
  }

  Future<Order> cancel(int id) async {
    final json = await _api.post<Map<String, dynamic>>('/orders/$id/cancel');
    return Order.fromJson(json);
  }
}

class WalletRepository {
  WalletRepository(this._api);

  final ApiClient _api;

  Future<Wallet> wallet() async {
    final json = await _api.get<Map<String, dynamic>>('/wallet');
    return Wallet.fromJson(json);
  }

  Future<Paged<WalletTransaction>> transactions({int page = 0, int size = 20}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/wallet/transactions',
      query: {'page': page, 'size': size},
    );
    return Paged.fromJson(json, WalletTransaction.fromJson);
  }

  Future<List<PaymentMethod>> paymentMethods() async {
    final json = await _api.get<List<dynamic>>('/wallet/payment-methods');
    return json.map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TopupRequest> createTopup({
    required int paymentMethodId,
    required int amount,
    required String referenceNo,
    String? senderName,
    String? senderPhone,
    String? screenshotUrl,
  }) async {
    final json = await _api.post<Map<String, dynamic>>('/wallet/topups', body: {
      'paymentMethodId': paymentMethodId,
      'amount': amount,
      'referenceNo': referenceNo,
      if (senderName != null && senderName.isNotEmpty) 'senderName': senderName,
      if (senderPhone != null && senderPhone.isNotEmpty) 'senderPhone': senderPhone,
      if (screenshotUrl != null && screenshotUrl.isNotEmpty) 'screenshotUrl': screenshotUrl,
    });
    return TopupRequest.fromJson(json);
  }

  Future<Paged<TopupRequest>> topups({int page = 0, int size = 20}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/wallet/topups',
      query: {'page': page, 'size': size},
    );
    return Paged.fromJson(json, TopupRequest.fromJson);
  }

  Future<TopupRequest> cancelTopup(int id) async {
    final json = await _api.post<Map<String, dynamic>>('/wallet/topups/$id/cancel');
    return TopupRequest.fromJson(json);
  }

  Future<String> uploadSlip({required List<int> bytes, required String fileName}) async {
    final json = await _api.upload<Map<String, dynamic>>(
      '/uploads/payment-slip',
      file: MultipartFile.fromBytes(bytes, filename: fileName),
    );
    return json['url'] as String;
  }
}

class MiscRepository {
  MiscRepository(this._api);

  final ApiClient _api;

  Future<Paged<AppNotification>> notifications({int page = 0, int size = 20}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/notifications',
      query: {'page': page, 'size': size},
    );
    return Paged.fromJson(json, AppNotification.fromJson);
  }

  Future<int> unreadCount() async {
    final json = await _api.get<Map<String, dynamic>>('/notifications/unread-count');
    return (json['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(int id) async {
    await _api.post<dynamic>('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.post<dynamic>('/notifications/read-all');
  }

  Future<Paged<SupportTicket>> tickets({int page = 0, int size = 20}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/support/tickets',
      query: {'page': page, 'size': size},
    );
    return Paged.fromJson(json, SupportTicket.fromJson);
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String message,
    int? orderId,
  }) async {
    final json = await _api.post<Map<String, dynamic>>('/support/tickets', body: {
      'subject': subject,
      'message': message,
      if (orderId != null) 'orderId': orderId,
    });
    return SupportTicket.fromJson(json);
  }
}
