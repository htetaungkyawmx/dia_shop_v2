import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/token_store.dart';
import '../data/admin_api.dart';
import '../models/admin_catalog.dart';
import '../models/dashboard.dart';
import '../models/misc.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../models/wallet.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError('tokenStoreProvider must be overridden'),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(tokenStoreProvider),
    onSessionExpired: () async => ref.read(authProvider.notifier).handleSessionExpiry(),
  );
});

final apiProvider = Provider<AdminApi>((ref) => AdminApi(ref.watch(apiClientProvider)));

// ------------------------------------------------------------------- theme

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _key = 'admin_theme_mode';

  @override
  ThemeMode build() => switch (ref.watch(sharedPreferencesProvider).getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

// -------------------------------------------------------------------- auth

class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final tokens = ref.read(tokenStoreProvider);
    if (!tokens.hasSession) return null;
    try {
      final user = await ref.read(apiProvider).me();
      // A customer account must never get into the admin panel, even if it
      // somehow holds a valid token.
      if (!user.isAdmin) {
        await tokens.clear();
        return null;
      }
      return user;
    } catch (_) {
      await tokens.clear();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(apiProvider).login(email, password);
      if (!result.user.isAdmin) {
        throw Exception('This account does not have admin access.');
      }
      await ref.read(tokenStoreProvider).save(
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
          );
      _invalidateAll();
      return result.user;
    });
  }

  Future<void> logout() async {
    final tokens = ref.read(tokenStoreProvider);
    try {
      await ref.read(apiProvider).logout(tokens.refreshToken);
    } catch (_) {
      // Sign out locally regardless.
    }
    await tokens.clear();
    _invalidateAll();
    state = const AsyncData(null);
  }

  Future<void> handleSessionExpiry() async {
    await ref.read(tokenStoreProvider).clear();
    _invalidateAll();
    state = const AsyncData(null);
  }

  void _invalidateAll() {
    ref.invalidate(dashboardProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(topupsProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(usersProvider);
    ref.invalidate(ticketsProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(paymentMethodsProvider);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

final isSignedInProvider = Provider<bool>((ref) => ref.watch(authProvider).value != null);

// --------------------------------------------------------------- dashboard

final dashboardProvider = FutureProvider<Dashboard>((ref) => ref.watch(apiProvider).dashboard());

final settingsProvider =
    FutureProvider<Map<String, String>>((ref) => ref.watch(apiProvider).settings());

// ------------------------------------------------------------------ orders

class OrderFilter {
  const OrderFilter({this.status, this.query});

  final OrderStatus? status;
  final String? query;

  @override
  bool operator ==(Object other) =>
      other is OrderFilter && other.status == status && other.query == query;

  @override
  int get hashCode => Object.hash(status, query);
}

final ordersProvider = FutureProvider.family<Paged<Order>, OrderFilter>(
  (ref, filter) => ref.watch(apiProvider).orders(query: filter.query, status: filter.status),
);

final orderProvider =
    FutureProvider.family<Order, int>((ref, id) => ref.watch(apiProvider).order(id));

// ------------------------------------------------------------------ topups

class TopupFilter {
  const TopupFilter({this.status, this.query});

  final TopupStatus? status;
  final String? query;

  @override
  bool operator ==(Object other) =>
      other is TopupFilter && other.status == status && other.query == query;

  @override
  int get hashCode => Object.hash(status, query);
}

final topupsProvider = FutureProvider.family<Paged<TopupRequest>, TopupFilter>(
  (ref, filter) => ref.watch(apiProvider).topups(query: filter.query, status: filter.status),
);

// ----------------------------------------------------------------- catalog

final categoriesProvider =
    FutureProvider<List<AdminCategory>>((ref) => ref.watch(apiProvider).categories());

class ProductFilter {
  const ProductFilter({this.query, this.categoryId, this.active});

  final String? query;
  final int? categoryId;
  final bool? active;

  @override
  bool operator ==(Object other) =>
      other is ProductFilter &&
      other.query == query &&
      other.categoryId == categoryId &&
      other.active == active;

  @override
  int get hashCode => Object.hash(query, categoryId, active);
}

final productsProvider = FutureProvider.family<Paged<AdminProduct>, ProductFilter>(
  (ref, filter) => ref.watch(apiProvider).products(
        query: filter.query,
        categoryId: filter.categoryId,
        active: filter.active,
      ),
);

final productProvider =
    FutureProvider.family<AdminProduct, int>((ref, id) => ref.watch(apiProvider).product(id));

final stockMovementsProvider = FutureProvider.family<Paged<StockMovement>, int>(
  (ref, variantId) => ref.watch(apiProvider).stockMovements(variantId),
);

final stockCodesProvider = FutureProvider.family<Paged<StockCode>, int>(
  (ref, variantId) => ref.watch(apiProvider).stockCodes(variantId),
);

// ------------------------------------------------------------------- users

class UserFilter {
  const UserFilter({this.query, this.status, this.role});

  final String? query;
  final String? status;
  final String? role;

  @override
  bool operator ==(Object other) =>
      other is UserFilter &&
      other.query == query &&
      other.status == status &&
      other.role == role;

  @override
  int get hashCode => Object.hash(query, status, role);
}

final usersProvider = FutureProvider.family<Paged<AdminUser>, UserFilter>(
  (ref, filter) => ref.watch(apiProvider).users(
        query: filter.query,
        status: filter.status,
        role: filter.role,
      ),
);

final userTransactionsProvider = FutureProvider.family<Paged<WalletTransaction>, int>(
  (ref, userId) => ref.watch(apiProvider).userTransactions(userId),
);

// ----------------------------------------------------------------- support

final ticketsProvider = FutureProvider.family<Paged<SupportTicket>, String?>(
  (ref, status) => ref.watch(apiProvider).tickets(status: status),
);

final paymentMethodsProvider =
    FutureProvider<List<PaymentMethod>>((ref) => ref.watch(apiProvider).paymentMethods());
