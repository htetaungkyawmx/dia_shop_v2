import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../providers/providers.dart';
import 'auth/change_password_dialog.dart';

/// Persistent navigation rail with live badges for the two queues that need
/// attention: pending orders and pending top-ups.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).value;
    final dashboard = ref.watch(dashboardProvider).value;
    final extended = MediaQuery.sizeOf(context).width >= 1180;

    final destinations = <_Dest>[
      const _Dest('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
      _Dest('Orders', Icons.receipt_long_outlined, Icons.receipt_long_rounded,
          badge: dashboard?.pendingOrders ?? 0),
      _Dest('Top-ups', Icons.account_balance_wallet_outlined,
          Icons.account_balance_wallet_rounded, badge: dashboard?.pendingTopups ?? 0),
      const _Dest('Products', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
      const _Dest('Customers', Icons.people_outline_rounded, Icons.people_rounded),
      _Dest('Support', Icons.support_agent_outlined, Icons.support_agent_rounded,
          badge: dashboard?.openTickets ?? 0),
      const _Dest('Settings', Icons.settings_outlined, Icons.settings_rounded),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 210,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            leading: Padding(
              padding: EdgeInsets.fromLTRB(extended ? 16 : 0, 18, extended ? 16 : 0, 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AdminTheme.brand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 18),
                  ),
                  if (extended) ...[
                    const SizedBox(width: 10),
                    Text('Dia Shop', style: theme.textTheme.titleSmall),
                  ],
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Toggle theme',
                        onPressed: () {
                          final current = ref.read(themeModeProvider);
                          ref.read(themeModeProvider.notifier).set(
                                current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                              );
                        },
                        icon: const Icon(Icons.brightness_6_outlined, size: 20),
                      ),
                      const SizedBox(height: 6),
                      PopupMenuButton<String>(
                        tooltip: user?.email ?? '',
                        onSelected: (value) async {
                          if (value == 'password') {
                            final changed = await ChangePasswordDialog.show(context);
                            // The server revokes every session on a change,
                            // so sign in again with the new password.
                            if (changed == true) {
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) context.go('/login');
                            }
                          }
                          if (value == 'logout') {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/login');
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.displayName ?? '',
                                    style: theme.textTheme.titleSmall),
                                Text(user?.email ?? '', style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'password',
                            child: Row(children: [
                              Icon(Icons.key_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Change password'),
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(children: [
                              Icon(Icons.logout_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Sign out'),
                            ]),
                          ),
                        ],
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AdminTheme.brand.withValues(alpha: 0.18),
                          child: Text(
                            user?.initials ?? '?',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: AdminTheme.brand),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: _Badged(count: d.badge, child: Icon(d.icon)),
                  selectedIcon: _Badged(count: d.badge, child: Icon(d.selectedIcon)),
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
}

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon, {this.badge = 0});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badge;
}

class _Badged extends StatelessWidget {
  const _Badged({required this.child, required this.count});

  final Widget child;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: child);
  }
}
