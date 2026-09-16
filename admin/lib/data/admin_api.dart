import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/admin_catalog.dart';
import '../models/dashboard.dart';
import '../models/misc.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../models/wallet.dart';

class AuthResult {
  const AuthResult(
      {required this.accessToken,
      required this.refreshToken,
      required this.user});

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// Every call the admin panel makes, in one place.
class AdminApi {
  AdminApi(this._api);

  final ApiClient _api;

  // ----------------------------------------------------------------- auth
  Future<AuthResult> login(String email, String password) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      auth: false,
      body: {'email': email, 'password': password, 'deviceInfo': 'admin-panel'},
    );
    return AuthResult.fromJson(json);
  }

  Future<AppUser> me() async =>
      AppUser.fromJson(await _api.get<Map<String, dynamic>>('/me'));

  Future<void> changePassword(
      {required String current, required String next}) async {
    await _api.post<dynamic>('/me/password',
        body: {'currentPassword': current, 'newPassword': next});
  }

  Future<void> logout(String? refreshToken) async {
    await _api.post<dynamic>('/auth/logout',
        body: {'refreshToken': refreshToken ?? ''});
  }

  /// Uploads a catalog or banner image and returns its public URL.
  Future<String> uploadImage(List<int> bytes,
      {required String fileName, String folder = 'catalog'}) async {
    final json = await _api.upload<Map<String, dynamic>>(
      '/admin/uploads/image?folder=$folder',
      file: MultipartFile.fromBytes(bytes, filename: fileName),
    );
    return json['url'] as String;
  }

  // ------------------------------------------------------------ dashboard
  Future<Dashboard> dashboard() async => Dashboard.fromJson(
      await _api.get<Map<String, dynamic>>('/admin/dashboard'));

  Future<Map<String, String>> settings() async {
    final json = await _api.get<Map<String, dynamic>>('/admin/settings');
    return json.map((key, value) => MapEntry(key, '$value'));
  }

  Future<Map<String, String>> updateSetting(String key, String value) async {
    final json = await _api.put<Map<String, dynamic>>(
      '/admin/settings',
      body: {'key': key, 'value': value},
    );
    return json.map((k, v) => MapEntry(k, '$v'));
  }

  Future<void> broadcast(
      {required String title, required String body, int? userId}) async {
    await _api.post<dynamic>('/admin/notifications', body: {
      'title': title,
      'body': body,
      if (userId != null) 'userId': userId,
    });
  }

  // --------------------------------------------------------------- orders
  Future<Paged<Order>> orders(
      {String? query, OrderStatus? status, int page = 0, int size = 25}) async {
    final json = await _api.get<Map<String, dynamic>>('/admin/orders', query: {
      'q': query,
      'status': status?.wireValue,
      'page': page,
      'size': size,
    });
    return Paged.fromJson(json, Order.fromJson);
  }

  Future<Order> order(int id) async =>
      Order.fromJson(await _api.get<Map<String, dynamic>>('/admin/orders/$id'));

  Future<Order> processOrder(int id) async => Order.fromJson(
      await _api.post<Map<String, dynamic>>('/admin/orders/$id/process'));

  Future<Order> completeOrder(int id, String? note) async => Order.fromJson(
        await _api.post<Map<String, dynamic>>('/admin/orders/$id/complete',
            body: {'adminNote': note}),
      );

  Future<Order> rejectOrder(int id, String reason, String? note) async =>
      Order.fromJson(
        await _api.post<Map<String, dynamic>>('/admin/orders/$id/reject',
            body: {'reason': reason, 'adminNote': note}),
      );

  Future<Order> refundOrder(int id, String? note) async => Order.fromJson(
        await _api.post<Map<String, dynamic>>('/admin/orders/$id/refund',
            body: {'adminNote': note}),
      );

  // --------------------------------------------------------------- topups
  Future<Paged<TopupRequest>> topups({
    String? query,
    TopupStatus? status,
    int page = 0,
    int size = 25,
  }) async {
    final json = await _api.get<Map<String, dynamic>>('/admin/topups', query: {
      'q': query,
      'status': status?.name.toUpperCase(),
      'page': page,
      'size': size,
    });
    return Paged.fromJson(json, TopupRequest.fromJson);
  }

  Future<TopupRequest> approveTopup(int id,
          {String? note, int? approvedAmount}) async =>
      TopupRequest.fromJson(
        await _api
            .post<Map<String, dynamic>>('/admin/topups/$id/approve', body: {
          'adminNote': note,
          if (approvedAmount != null) 'approvedAmount': approvedAmount,
        }),
      );

  Future<TopupRequest> rejectTopup(int id, {String? note}) async =>
      TopupRequest.fromJson(
        await _api.post<Map<String, dynamic>>('/admin/topups/$id/reject',
            body: {'adminNote': note}),
      );

  // -------------------------------------------------------------- catalog
  Future<List<AdminCategory>> categories() async {
    final json = await _api.get<List<dynamic>>('/admin/categories');
    return json
        .map((e) => AdminCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminCategory> saveCategory(Map<String, dynamic> body,
      {int? id}) async {
    final json = id == null
        ? await _api.post<Map<String, dynamic>>('/admin/categories', body: body)
        : await _api.put<Map<String, dynamic>>('/admin/categories/$id',
            body: body);
    return AdminCategory.fromJson(json);
  }

  Future<Paged<AdminProduct>> products({
    String? query,
    int? categoryId,
    bool? active,
    int page = 0,
    int size = 50,
  }) async {
    final json =
        await _api.get<Map<String, dynamic>>('/admin/products', query: {
      'q': query,
      'categoryId': categoryId,
      'active': active,
      'page': page,
      'size': size,
    });
    return Paged.fromJson(json, AdminProduct.fromJson);
  }

  Future<AdminProduct> product(int id) async => AdminProduct.fromJson(
      await _api.get<Map<String, dynamic>>('/admin/products/$id'));

  Future<AdminProduct> saveProduct(Map<String, dynamic> body, {int? id}) async {
    final json = id == null
        ? await _api.post<Map<String, dynamic>>('/admin/products', body: body)
        : await _api.put<Map<String, dynamic>>('/admin/products/$id',
            body: body);
    return AdminProduct.fromJson(json);
  }

  Future<void> archiveProduct(int id) async {
    await _api.delete<dynamic>('/admin/products/$id');
  }

  Future<AdminVariant> saveVariant(Map<String, dynamic> body,
      {int? productId, int? variantId}) async {
    final json = variantId == null
        ? await _api.post<Map<String, dynamic>>(
            '/admin/products/$productId/variants',
            body: body)
        : await _api.put<Map<String, dynamic>>('/admin/variants/$variantId',
            body: body);
    return AdminVariant.fromJson(json);
  }

  Future<void> archiveVariant(int id) async {
    await _api.delete<dynamic>('/admin/variants/$id');
  }

  // ---------------------------------------------------------------- stock
  Future<AdminVariant> adjustStock(int variantId,
      {required int delta, required String reason, String? note}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/admin/variants/$variantId/stock/adjust',
      body: {'delta': delta, 'reason': reason, 'note': note},
    );
    return AdminVariant.fromJson(json);
  }

  Future<AdminVariant> setStock(int variantId,
      {required int quantity, required String note}) async {
    final json = await _api.put<Map<String, dynamic>>(
      '/admin/variants/$variantId/stock',
      body: {'quantity': quantity, 'note': note},
    );
    return AdminVariant.fromJson(json);
  }

  Future<Paged<StockMovement>> stockMovements(int variantId,
      {int page = 0, int size = 30}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/admin/variants/$variantId/stock/movements',
      query: {'page': page, 'size': size},
    );
    return Paged.fromJson(json, StockMovement.fromJson);
  }

  Future<Map<String, int>> addStockCodes(int variantId, List<String> codes,
      {String? secret}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/admin/variants/$variantId/stock/codes',
      body: {
        'codes': codes,
        if (secret != null && secret.isNotEmpty) 'secret': secret
      },
    );
    return {
      'added': (json['added'] as num?)?.toInt() ?? 0,
      'skippedDuplicates': (json['skippedDuplicates'] as num?)?.toInt() ?? 0,
      'availableNow': (json['availableNow'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Paged<StockCode>> stockCodes(int variantId,
      {int page = 0, int size = 30}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/admin/variants/$variantId/stock/codes',
      query: {'page': page, 'size': size},
    );
    return Paged.fromJson(json, StockCode.fromJson);
  }

  // ---------------------------------------------------------------- users
  Future<Paged<AdminUser>> users({
    String? query,
    String? status,
    String? role,
    int page = 0,
    int size = 25,
  }) async {
    final json = await _api.get<Map<String, dynamic>>('/admin/users', query: {
      'q': query,
      'status': status,
      'role': role,
      'page': page,
      'size': size,
    });
    return Paged.fromJson(json, AdminUser.fromJson);
  }

  Future<AdminUser> updateUser(int id, Map<String, dynamic> body) async =>
      AdminUser.fromJson(await _api
          .patch<Map<String, dynamic>>('/admin/users/$id', body: body));

  /// Returns the temporary password to hand to the customer.
  Future<String> resetPassword(int userId) async {
    final json = await _api
        .post<Map<String, dynamic>>('/admin/users/$userId/reset-password');
    return json['temporaryPassword'] as String;
  }

  Future<AdminUser> adjustBalance(int id,
          {required int amount, required String reason}) async =>
      AdminUser.fromJson(
        await _api.post<Map<String, dynamic>>('/admin/users/$id/balance',
            body: {'amount': amount, 'reason': reason}),
      );

  Future<Paged<WalletTransaction>> userTransactions(int id,
      {int page = 0, int size = 30}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/admin/users/$id/transactions',
      query: {'page': page, 'size': size},
    );
    return Paged.fromJson(json, WalletTransaction.fromJson);
  }

  Future<AdminUser> createStaff({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async =>
      AdminUser.fromJson(
          await _api.post<Map<String, dynamic>>('/admin/staff', body: {
        'email': email,
        'password': password,
        'displayName': displayName,
        'role': role,
      }));

  // -------------------------------------------------------------- support
  Future<Paged<SupportTicket>> tickets(
      {String? status, int page = 0, int size = 25}) async {
    final json = await _api.get<Map<String, dynamic>>('/admin/tickets', query: {
      'status': status,
      'page': page,
      'size': size,
    });
    return Paged.fromJson(json, SupportTicket.fromJson);
  }

  Future<SupportTicket> replyTicket(int id,
          {required String reply, required String status}) async =>
      SupportTicket.fromJson(
        await _api.post<Map<String, dynamic>>('/admin/tickets/$id/reply',
            body: {'reply': reply, 'status': status}),
      );

  // ------------------------------------------------------- payment methods
  Future<List<PaymentMethod>> paymentMethods() async {
    final json = await _api.get<List<dynamic>>('/admin/payment-methods');
    return json
        .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentMethod> savePaymentMethod(Map<String, dynamic> body,
      {int? id}) async {
    final json = id == null
        ? await _api.post<Map<String, dynamic>>('/admin/payment-methods',
            body: body)
        : await _api.put<Map<String, dynamic>>('/admin/payment-methods/$id',
            body: body);
    return PaymentMethod.fromJson(json);
  }
}
