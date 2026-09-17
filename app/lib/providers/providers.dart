import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/token_store.dart';
import '../data/repositories.dart';
import '../models/catalog.dart';
import '../models/misc.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../models/wallet.dart';

// --------------------------------------------------------------- foundations

/// Overridden in main() once the async initialisation is done.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError('tokenStoreProvider must be overridden'),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  return ApiClient(
    tokens,
    onSessionExpired: () async =>
        ref.read(authProvider.notifier).handleSessionExpiry(),
  );
});

final authRepositoryProvider =
    Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
final catalogRepositoryProvider =
    Provider((ref) => CatalogRepository(ref.watch(apiClientProvider)));
final orderRepositoryProvider =
    Provider((ref) => OrderRepository(ref.watch(apiClientProvider)));
final walletRepositoryProvider =
    Provider((ref) => WalletRepository(ref.watch(apiClientProvider)));
final miscRepositoryProvider =
    Provider((ref) => MiscRepository(ref.watch(apiClientProvider)));

// ------------------------------------------------------------------ settings

class AppSettings {
  const AppSettings({required this.themeMode, required this.locale});

  final ThemeMode themeMode;
  final Locale locale;

  AppSettings copyWith({ThemeMode? themeMode, Locale? locale}) => AppSettings(
      themeMode: themeMode ?? this.themeMode, locale: locale ?? this.locale);
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _themeKey = 'settings_theme_mode';
  static const _localeKey = 'settings_locale';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      // Dark by default rather than following the device: the shop is
      // designed dark - game artwork sits on a deep navy - and a customer on a
      // light-mode phone would otherwise land on the pale theme.
      themeMode: switch (prefs.getString(_themeKey)) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      },
      // Burmese is the default: it is what most customers read.
      locale: Locale(prefs.getString(_localeKey) ?? 'my'),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_themeKey, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_localeKey, locale.languageCode);
    // Keep the server copy in sync so notifications arrive in the same language.
    if (ref.read(authProvider).value != null) {
      try {
        await ref
            .read(authRepositoryProvider)
            .updateProfile(locale: locale.languageCode);
      } catch (_) {
        // A failed sync is not worth interrupting the user for.
      }
    }
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ---------------------------------------------------------------------- auth

class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final tokens = ref.read(tokenStoreProvider);
    if (!tokens.hasSession) return null;
    try {
      return await ref.read(authRepositoryProvider).me();
    } catch (_) {
      // A stale or revoked session should land the user on the sign-in screen,
      // not on an error page.
      await tokens.clear();
      return null;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    // copyWithPrevious keeps hasValue true, so the router does not treat a
    // sign-in in progress as the cold-start session check.
    state = const AsyncLoading<AppUser?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final result = await ref.read(authRepositoryProvider).register(
            email: email,
            password: password,
            displayName: displayName,
            phone: phone,
          );
      await _store(result);
      return result.user;
    });
  }

  Future<void> login({required String email, required String password}) async {
    // copyWithPrevious keeps hasValue true, so the router does not treat a
    // sign-in in progress as the cold-start session check.
    state = const AsyncLoading<AppUser?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final result = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      await _store(result);
      return result.user;
    });
  }

  Future<void> loginWithGoogle(String idToken) async {
    // copyWithPrevious keeps hasValue true, so the router does not treat a
    // sign-in in progress as the cold-start session check.
    state = const AsyncLoading<AppUser?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final result =
          await ref.read(authRepositoryProvider).loginWithGoogle(idToken);
      await _store(result);
      return result.user;
    });
  }

  Future<void> _store(AuthResult result) async {
    await ref.read(tokenStoreProvider).save(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
        );
    _invalidateUserScopedData();
  }

  Future<void> logout() async {
    final tokens = ref.read(tokenStoreProvider);
    try {
      await ref.read(authRepositoryProvider).logout(tokens.refreshToken);
    } catch (_) {
      // Sign out locally even if the server call fails.
    }
    await tokens.clear();
    _invalidateUserScopedData();
    state = const AsyncData(null);
  }

  /// Called by the API client when a refresh fails: drop straight to signed-out.
  Future<void> handleSessionExpiry() async {
    await ref.read(tokenStoreProvider).clear();
    _invalidateUserScopedData();
    state = const AsyncData(null);
  }

  Future<void> refreshProfile() async {
    if (state.value == null) return;
    final user = await ref.read(authRepositoryProvider).me();
    state = AsyncData(user);
  }

  Future<void> updateProfile(
      {String? displayName, String? phone, String? photoUrl}) async {
    final user = await ref.read(authRepositoryProvider).updateProfile(
          displayName: displayName,
          phone: phone,
          photoUrl: photoUrl,
        );
    state = AsyncData(user);
  }

  Future<void> uploadPhoto(
      {required List<int> bytes, required String fileName}) async {
    final user = await ref
        .read(authRepositoryProvider)
        .uploadPhoto(bytes: bytes, fileName: fileName);
    state = AsyncData(user);
  }

  void _invalidateUserScopedData() {
    ref.invalidate(accountStatsProvider);
    ref.invalidate(walletProvider);
    ref.invalidate(walletTransactionsProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(topupsProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(ticketsProvider);
    ref.read(cartProvider.notifier).clear();
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

final isSignedInProvider =
    Provider<bool>((ref) => ref.watch(authProvider).value != null);

final accountStatsProvider = FutureProvider<AccountStats?>((ref) async {
  if (!ref.watch(isSignedInProvider)) return null;
  return ref.watch(authRepositoryProvider).stats();
});

// ------------------------------------------------------------------- catalog

final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  try {
    return await ref.watch(catalogRepositoryProvider).config();
  } catch (_) {
    // The shop should still open if the config endpoint hiccups.
    return AppConfig.fallback;
  }
});

final homeProvider = FutureProvider<HomeData>(
  (ref) => ref.watch(catalogRepositoryProvider).home(),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).categories(),
);

/// Query for the shop list: either a category, a search term, or both.
class ProductQuery {
  const ProductQuery({this.category, this.search});

  final String? category;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.category == category &&
      other.search == search;

  @override
  int get hashCode => Object.hash(category, search);
}

final productsProvider =
    FutureProvider.family<List<ProductSummary>, ProductQuery>(
        (ref, query) async {
  return ref.watch(catalogRepositoryProvider).products(
        category: query.category,
        query: query.search,
      );
});

/// Payment accounts are public: the footer lists them for signed-out visitors.
final publicPaymentMethodsProvider = FutureProvider<List<PaymentMethod>>(
  (ref) => ref.watch(catalogRepositoryProvider).paymentMethods(),
);

final productProvider = FutureProvider.family<ProductDetail, String>(
  (ref, slug) => ref.watch(catalogRepositoryProvider).product(slug),
);

// -------------------------------------------------------------------- wallet

final walletProvider = FutureProvider<Wallet>((ref) async {
  if (!ref.watch(isSignedInProvider)) {
    return const Wallet(balance: 0, pendingTopupAmount: 0);
  }
  return ref.watch(walletRepositoryProvider).wallet();
});

final walletTransactionsProvider =
    FutureProvider<Paged<WalletTransaction>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return Paged.empty();
  return ref.watch(walletRepositoryProvider).transactions(size: 50);
});

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>(
  (ref) => ref.watch(walletRepositoryProvider).paymentMethods(),
);

final topupsProvider = FutureProvider<Paged<TopupRequest>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return Paged.empty();
  return ref.watch(walletRepositoryProvider).topups(size: 50);
});

// -------------------------------------------------------------------- orders

final ordersProvider =
    FutureProvider.family<Paged<Order>, OrderStatus?>((ref, status) async {
  if (!ref.watch(isSignedInProvider)) return Paged.empty();
  return ref.watch(orderRepositoryProvider).list(status: status, size: 50);
});

final orderProvider = FutureProvider.family<Order, int>(
  (ref, id) => ref.watch(orderRepositoryProvider).get(id),
);

// ---------------------------------------------------------------------- misc

final notificationsProvider =
    FutureProvider<Paged<AppNotification>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return Paged.empty();
  return ref.watch(miscRepositoryProvider).notifications(size: 50);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(isSignedInProvider)) return 0;
  return ref.watch(miscRepositoryProvider).unreadCount();
});

final ticketsProvider = FutureProvider<Paged<SupportTicket>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return Paged.empty();
  return ref.watch(miscRepositoryProvider).tickets();
});

// ---------------------------------------------------------------------- cart

/// Single-item basket today — the checkout flow already supports several lines,
/// so adding a real multi-item cart later only means keeping more entries here.
class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  void replaceWith(CartLine line) => state = [line];

  void add(CartLine line) => state = [...state, line];

  void removeAt(int index) => state = [...state]..removeAt(index);

  void clear() => state = const [];

  int get total => state.fold(0, (sum, line) => sum + line.lineTotal);
}

final cartProvider =
    NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);
