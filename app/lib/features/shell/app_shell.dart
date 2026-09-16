import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../providers/providers.dart';

/// Bottom navigation on phones, a side rail from tablet width up — the same
/// destinations either way, so the web build feels native at any size.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final destinations = <_Destination>[
      _Destination(strings.home, Icons.home_outlined, Icons.home_rounded),
      _Destination(strings.shop, Icons.storefront_outlined, Icons.storefront_rounded),
      _Destination(strings.orders, Icons.receipt_long_outlined, Icons.receipt_long_rounded),
      _Destination(strings.wallet, Icons.account_balance_wallet_outlined,
          Icons.account_balance_wallet_rounded),
      _Destination(strings.profile, Icons.person_outline_rounded, Icons.person_rounded,
          badge: unread),
    ];

    void go(int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: _WithBadge(count: d.badge, child: Icon(d.icon)),
                    selectedIcon: _WithBadge(count: d.badge, child: Icon(d.selectedIcon)),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: go,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: _WithBadge(count: d.badge, child: Icon(d.icon)),
              selectedIcon: _WithBadge(count: d.badge, child: Icon(d.selectedIcon)),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon, {this.badge = 0});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badge;
}

class _WithBadge extends StatelessWidget {
  const _WithBadge({required this.child, required this.count});

  final Widget child;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: child,
    );
  }
}
