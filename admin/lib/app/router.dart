import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/auth/splash_page.dart';
import '../features/catalog/products_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/orders/orders_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell_page.dart';
import '../features/support/support_page.dart';
import '../features/topups/topups_page.dart';
import '../features/users/users_page.dart';
import '../providers/providers.dart';

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
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) {
        if (location == '/splash') return null;
        return Uri(
            path: '/splash',
            queryParameters: {'from': state.uri.toString()}).toString();
      }
      final from = state.uri.queryParameters['from'];
      final back = (from != null &&
              from.startsWith('/') &&
              !from.startsWith('//') &&
              !from.startsWith('/splash') &&
              !from.startsWith('/login'))
          ? from
          : '/';
      final signedIn = auth.value != null;
      if (!signedIn) return location == '/login' ? null : '/login';
      if (location == '/login' || location == '/splash') return back;
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/', builder: (context, state) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/topups',
                builder: (context, state) => const TopupsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/products',
                builder: (context, state) => const ProductsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/users', builder: (context, state) => const UsersPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/support',
                builder: (context, state) => const SupportPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage()),
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
