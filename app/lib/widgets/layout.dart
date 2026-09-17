import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../l10n/strings.dart';
import '../providers/providers.dart';
import 'catalog_widgets.dart';

/// Layout thresholds shared by every screen.
///
/// Below [wide] the app behaves like a phone app (app bar + bottom navigation).
/// From [wide] up it becomes a website: a fixed header, full-width content in a
/// centred container, and a footer.
class Breakpoints {
  const Breakpoints._();

  static const double wide = 900;
  static const double desktop = 1200;
  static const double container = 1280;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// Side padding that grows with the window so content never touches the edge.
  static double gutter(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktop) return 40;
    if (width >= wide) return 28;
    return 16;
  }
}

/// Centres content in the site container, with responsive side padding.
class PageContainer extends StatelessWidget {
  const PageContainer(
      {super.key,
      required this.child,
      this.maxWidth = Breakpoints.container,
      this.padding});

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(horizontal: Breakpoints.gutter(context)),
          child: child,
        ),
      ),
    );
  }
}

/// Opens sign-in and comes back to the current page afterwards.
void pushLogin(BuildContext context, {bool register = false}) {
  final here = GoRouterState.of(context).uri.toString();
  context.push(Uri(
      path: register ? '/register' : '/login',
      queryParameters: {'from': here}).toString());
}

// ------------------------------------------------------------------- brand

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Game Store',
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.logoSize = 38, this.onTap});

  final double logoSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: logoSize),
            const SizedBox(width: 10),
            Text(
              Strings.of(context).appName,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ header

class WebHeader extends ConsumerWidget {
  const WebHeader({super.key});

  static const double height = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final user = ref.watch(authProvider).value;
    final location = GoRouterState.of(context).uri.path;
    final showSearchField = Breakpoints.isDesktop(context);

    final links = <(String, String)>[
      (strings.home, '/'),
      (strings.shop, '/shop'),
      if (user != null) (strings.orders, '/orders'),
      if (user != null) (strings.wallet, '/wallet'),
    ];

    bool isActive(String route) => route == '/'
        ? location == '/'
        : location == route || location.startsWith('$route/');

    // Frosted bar: the page scrolls under a translucent, blurred header with a
    // faint gold hairline, rather than butting against a solid block.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height,
          decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.72),
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.gold.withValues(alpha: 0.18)))),
          child: PageContainer(
            child: Row(
              children: [
                BrandMark(onTap: () => context.go('/')),
                const SizedBox(width: 28),
                for (final (label, route) in links)
                  _NavLink(
                      label: label,
                      active: isActive(route),
                      onTap: () => context.go(route)),
                const Spacer(),
                if (showSearchField)
                  SizedBox(
                    width: 260,
                    child: _HeaderSearch(hint: strings.searchHint),
                  )
                else
                  IconButton(
                    tooltip: strings.search,
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.search_rounded),
                  ),
                const SizedBox(width: 6),
                const _LanguageToggle(),
                if (user == null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: () => pushLogin(context),
                      child: Text(strings.signIn)),
                  const SizedBox(width: 6),
                  FilledButton(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                    onPressed: () => pushLogin(context, register: true),
                    child: Text(strings.signUp),
                  ),
                ] else ...[
                  const SizedBox(width: 6),
                  BalancePill(
                    balance: ref.watch(walletProvider).value?.balance ??
                        user.balance,
                    onTap: () => context.push('/wallet/topup'),
                  ),
                  const _NotificationBell(),
                  const _AccountMenu(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink(
      {required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: WebHeader.height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: active ? theme.colorScheme.primary : Colors.transparent,
                width: 2.5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}

class _HeaderSearch extends StatelessWidget {
  const _HeaderSearch({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/search'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                size: 19, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final burmese = ref.watch(settingsProvider).locale.languageCode == 'my';
    return TextButton(
      onPressed: () => ref
          .read(settingsProvider.notifier)
          .setLocale(Locale(burmese ? 'en' : 'my')),
      child: Text(burmese ? 'EN' : 'MM'),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return IconButton(
      tooltip: Strings.of(context).notifications,
      onPressed: () => context.push('/notifications'),
      icon: unread > 0
          ? Badge(
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications_none_rounded))
          : const Icon(Icons.notifications_none_rounded),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).value!;

    PopupMenuItem<String> item(String value, IconData icon, String label) =>
        PopupMenuItem(
          value: value,
          child: Row(children: [
            Icon(icon, size: 19),
            const SizedBox(width: 12),
            Text(label)
          ]),
        );

    return PopupMenuButton<String>(
      tooltip: user.displayName,
      offset: const Offset(0, 52),
      onSelected: (value) async {
        if (value == 'logout') {
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) context.go('/');
        } else {
          context.go(value);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.displayName, style: theme.textTheme.titleSmall),
              Text(user.email, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        item('/profile', Icons.person_outline_rounded, strings.profile),
        item('/orders', Icons.receipt_long_outlined, strings.myOrders),
        item(
            '/wallet', Icons.account_balance_wallet_outlined, strings.myWallet),
        item('/support', Icons.support_agent_rounded, strings.support),
        const PopupMenuDivider(),
        item('logout', Icons.logout_rounded, strings.signOut),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.16),
          backgroundImage:
              user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
          child: user.photoUrl != null
              ? null
              : Text(user.initials,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary)),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- page

/// Screen scaffold that is an app screen on phones and a web page on wide
/// windows. On wide windows the page title sits under the site header with a
/// back link, instead of in a Material app bar.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.body,
    this.title,
    this.actions = const [],
    this.bottomBar,
    this.floatingActionButton,
    this.maxWidth = 720,
    this.showBack = true,
    this.scrollsItself = true,
  });

  final Widget body;
  final String? title;
  final List<Widget> actions;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// Content width on wide screens. Forms read best narrow; catalogues use
  /// the full container.
  final double maxWidth;
  final bool showBack;

  /// True when [body] already contains its own scroll view.
  final bool scrollsItself;

  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.isWide(context)) {
      return Scaffold(
        appBar: title == null && actions.isEmpty
            ? null
            : AppBar(
                // Opened from a shared link there is nothing to go back to,
                // so offer a way home instead of leaving the user stuck.
                leading: showBack && !context.canPop()
                    ? IconButton(
                        tooltip: Strings.of(context).home,
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_rounded),
                      )
                    : null,
                title: title == null ? null : Text(title!),
                actions: actions),
        body: body,
        bottomNavigationBar: bottomBar,
        floatingActionButton: floatingActionButton,
      );
    }

    final theme = Theme.of(context);
    final canPop = showBack && context.canPop();
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          const WebHeader(),
          if (title != null || actions.isNotEmpty)
            // Same width and 16px inset as the page bodies (MaxWidthBody +
            // ListView padding), so the title lines up with the content.
            PageContainer(
              maxWidth: maxWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 6),
                child: Row(
                  children: [
                    if (canPop) ...[
                      IconButton.filledTonal(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      ),
                      const SizedBox(width: 14),
                    ],
                    if (title != null)
                      Expanded(
                          child: Text(title!,
                              style: theme.textTheme.headlineSmall)),
                    if (title == null) const Spacer(),
                    ...actions,
                  ],
                ),
              ),
            ),
          Expanded(
              child: PageContainer(
                  maxWidth: maxWidth, padding: EdgeInsets.zero, child: body)),
          if (bottomBar != null)
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.dividerColor))),
              child: PageContainer(
                  maxWidth: maxWidth,
                  padding: EdgeInsets.zero,
                  child: bottomBar!),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ footer

class SiteFooter extends ConsumerWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final config = ref.watch(appConfigProvider).value;
    final methods = ref.watch(publicPaymentMethodsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.6);

    Widget column(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            ...children,
          ],
        );

    Widget link(String label, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(label, style: muted)),
        );

    final support = config?.support ?? const <String, String>{};
    final supportLinks = <Widget>[
      link(strings.contactSupport, () => context.push('/support')),
      link(strings.faq, () => context.push('/faq')),
      if ((support['messenger'] ?? '').isNotEmpty)
        link('Messenger', () => _open(support['messenger']!)),
      if ((support['telegram'] ?? '').isNotEmpty)
        link('Telegram', () => _open(support['telegram']!)),
      if ((support['viber'] ?? '').isNotEmpty)
        link('Viber', () => _open(support['viber']!)),
      if ((support['phone'] ?? '').isNotEmpty)
        link(support['phone']!, () => _open('tel:${support['phone']}')),
    ];

    final columns = <Widget>[
      SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(logoSize: 44),
            const SizedBox(height: 12),
            Text(strings.tagline, style: muted),
            if (methods.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(strings.footerPayments, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in methods)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(m.name, style: theme.textTheme.labelMedium),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      column(strings.footerShop, [
        for (final c in categories)
          link(c.localisedName(strings.isBurmese),
              () => context.go('/shop?category=${c.slug}')),
      ]),
      column(strings.footerAccount, [
        link(strings.myOrders, () => context.go('/orders')),
        link(strings.myWallet, () => context.go('/wallet')),
        link(strings.topUp, () => context.push('/wallet/topup')),
        link(strings.profile, () => context.go('/profile')),
      ]),
      column(strings.footerHelp, supportLinks),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: PageContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 64, runSpacing: 32, children: columns),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                  '© ${DateTime.now().year} ${strings.appName}. ${strings.allRightsReserved}',
                  style: muted),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Small helper for section titles on web pages.
class WebSectionTitle extends StatelessWidget {
  const WebSectionTitle(
      {super.key, required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = Breakpoints.isWide(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: (wide
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleMedium)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// Accent colour for decorative icons in feature strips.
Color accentFor(int index) => const [
      AppTheme.brand,
      AppTheme.success,
      AppTheme.info,
      AppTheme.gold
    ][index % 4];
