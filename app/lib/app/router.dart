import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/catalog/product_page.dart';
import '../features/catalog/search_page.dart';
import '../features/catalog/shop_page.dart';
import '../features/checkout/checkout_page.dart';
import '../features/checkout/order_success_page.dart';
import '../features/home/home_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/orders/order_detail_page.dart';
import '../features/orders/orders_page.dart';
import '../features/profile/change_password_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/profile_page.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/splash_page.dart';
import '../features/support/support_page.dart';
import '../features/wallet/topup_page.dart';
import '../features/wallet/wallet_page.dart';
import '../providers/providers.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Routes a signed-out visitor may open. Everything else redirects to sign-in.
const _publicPrefixes = <String>['/login', '/register', '/shop', '/product', '/search'];


/// Re-runs the redirect when the session changes.
///
/// The router is built once and kept; watching [authProvider] here instead
/// would rebuild the whole GoRouter on every auth change, which briefly
/// rebuilds the route tree before the new redirect applies.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      // Hold on the splash until the first auth check finishes, otherwise a
      // signed-in user briefly lands on the login screen on a cold start.
      if (auth.isLoading) return state.matchedLocation == '/splash' ? null : '/splash';

      final signedIn = auth.value != null;
      final location = state.matchedLocation;
      final isPublic = location == '/' ||
          _publicPrefixes.any((prefix) => location.startsWith(prefix));

      if (!signedIn && !isPublic) return '/login';
      if (signedIn && (location == '/login' || location == '/register' || location == '/splash')) {
        return '/';
      }
      if (location == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(
        path: '/product/:slug',
        builder: (context, state) => ProductPage(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutPage()),
      GoRoute(
        path: '/order-success/:id',
        builder: (context, state) =>
            OrderSuccessPage(orderId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailPage(orderId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/wallet/topup', builder: (context, state) => const TopupPage()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsPage()),
      GoRoute(path: '/support', builder: (context, state) => const SupportPage()),
      GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfilePage()),
      GoRoute(path: '/profile/password', builder: (context, state) => const ChangePasswordPage()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/shop',
              builder: (context, state) =>
                  ShopPage(initialCategory: state.uri.queryParameters['category']),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/orders', builder: (context, state) => const OrdersPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/wallet', builder: (context, state) => const WalletPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
