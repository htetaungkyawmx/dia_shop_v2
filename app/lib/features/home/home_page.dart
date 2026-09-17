import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../models/catalog.dart' as catalog;
import '../../models/order.dart';
import '../../providers/providers.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/layout.dart';
import '../orders/order_status_ui.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final wide = Breakpoints.isWide(context);

    Future<void> refresh() async {
      ref.invalidate(homeProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(ordersProvider);
      await ref.read(homeProvider.future);
    }

    final content = home.when(
      loading: () => const _HomeSkeleton(),
      error: (error, _) => ListView(
        children: [
          const SizedBox(height: 120),
          ErrorView(error: error, onRetry: () => ref.invalidate(homeProvider)),
        ],
      ),
      data: (data) =>
          RefreshIndicator(onRefresh: refresh, child: _HomeContent(data: data)),
    );

    if (wide) {
      return Scaffold(
          body:
              Column(children: [const WebHeader(), Expanded(child: content)]));
    }
    return Scaffold(body: SafeArea(bottom: false, child: content));
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.data});

  final catalog.HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final wide = Breakpoints.isWide(context);
    final gap = wide ? 48.0 : 28.0;

    // Every product, grouped under its category, so the home page is the whole
    // catalogue instead of a teaser that sends the visitor somewhere else.
    final all = ref.watch(productsProvider(const ProductQuery()));
    final products = all.value ?? data.featured;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (!wide)
          const PageContainer(
            child: Padding(
                padding: EdgeInsets.only(top: 8), child: _MobileTopBar()),
          ),
        if (data.maintenance)
          PageContainer(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _MaintenanceBanner(
                  title: strings.maintenanceTitle,
                  message: data.maintenanceMessage),
            ),
          ),
        SizedBox(height: wide ? 28 : 16),
        PageContainer(child: _Hero(banners: data.banners)),
        SizedBox(height: wide ? 28 : 20),
        if (data.categories.isNotEmpty)
          PageContainer(child: _CategoryStrip(categories: data.categories)),
        const _RecentOrders(),
        for (final category in data.categories) ...[
          if (products.any((p) => p.categorySlug == category.slug)) ...[
            SizedBox(height: gap),
            _CategorySection(
              title: category.localisedName(strings.isBurmese),
              products: products
                  .where((p) => p.categorySlug == category.slug)
                  .toList(),
            ),
          ],
        ],
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: EmptyView(
              icon: Icons.inventory_2_outlined,
              title: strings.noProducts,
              message: strings.noProductsBody,
            ),
          ),
        SizedBox(height: gap),
        if (wide) const SiteFooter() else const SizedBox(height: 32),
      ],
    );
  }
}

/// A category's products, showing a first page and growing in place when the
/// visitor asks for more - rather than sending them to a separate list.
class _CategorySection extends StatefulWidget {
  const _CategorySection({required this.title, required this.products});

  final String title;
  final List<catalog.ProductSummary> products;

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  static const _pageSize = 12;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final visible = widget.products.take(_shown).toList();
    final remaining = widget.products.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageContainer(child: WebSectionTitle(title: widget.title)),
        const SizedBox(height: 16),
        PageContainer(child: _GameGrid(products: visible)),
        if (remaining > 0) ...[
          const SizedBox(height: 22),
          Center(
            child: SizedBox(
              width: 210,
              child: OutlinedButton(
                onPressed: () => setState(() => _shown += _pageSize),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  foregroundColor: Colors.white,
                ),
                child: Text(strings.viewAll),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MobileTopBar extends ConsumerWidget {
  const _MobileTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final user = ref.watch(authProvider).value;
    final balance =
        ref.watch(walletProvider).value?.balance ?? user?.balance ?? 0;
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Column(
      children: [
        Row(
          children: [
            const AppLogo(size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user == null
                        ? strings.appName
                        : (strings.isBurmese ? 'မင်္ဂလာပါ' : 'Hello'),
                    style: user == null
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (user != null)
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                ],
              ),
            ),
            if (user != null) ...[
              BalancePill(
                  balance: balance, onTap: () => context.push('/wallet/topup')),
              IconButton(
                onPressed: () => context.push('/notifications'),
                icon: unread > 0
                    ? Badge(
                        label: Text(unread > 99 ? '99+' : '$unread'),
                        child: const Icon(Icons.notifications_none_rounded),
                      )
                    : const Icon(Icons.notifications_none_rounded),
              ),
            ] else
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => pushLogin(context),
                child: Text(strings.signIn),
              ),
          ],
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () => context.push('/search'),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.searchHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------ hero

class _Hero extends StatelessWidget {
  const _Hero({required this.banners});

  final List<catalog.Banner> banners;

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    // One banner across the full width. The wallet panel that used to sit
    // beside it competed with the artwork; the balance is in the header.
    return banners.isEmpty
        ? const _WelcomeBanner()
        : _BannerCarousel(banners: banners, height: wide ? 260 : 150);
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    return Container(
      height: Breakpoints.isWide(context) ? 340 : 170,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.appName,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Text(strings.tagline,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const AppLogo(size: 110),
        ],
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners, required this.height});

  final List<catalog.Banner> banners;
  final double height;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer =
          Timer.periodic(const Duration(seconds: 6), (_) => _go(_index + 1));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (!mounted || !_controller.hasClients) return;
    _controller.animateToPage(
      index % widget.banners.length,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _open(catalog.Banner banner) {
    switch (banner.linkType) {
      case 'PRODUCT':
        if (banner.linkValue != null) {
          context.push('/product/${banner.linkValue}');
        }
      case 'CATEGORY':
        if (banner.linkValue != null) {
          context.go('/shop?category=${banner.linkValue}');
        }
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final many = widget.banners.length > 1;
    final large = widget.height > 200;

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (index) => setState(() => _index = index),
              itemCount: widget.banners.length,
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return GestureDetector(
                  onTap: () => _open(banner),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // A slide may carry a wide banner or a square product
                      // logo, so the image is contained over a deep gradient
                      // rather than cropped to fill.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1B1F31), Color(0xFF090B13)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            large ? 24 : 12, large ? 20 : 10,
                            large ? 24 : 12, large ? 56 : 34),
                        child: AppImage(
                            url: banner.imageUrl,
                            radius: 0,
                            fit: BoxFit.contain,
                            fallbackIcon: Icons.campaign_rounded),
                      ),
                      if ((banner.title ?? '').isNotEmpty)
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: [Color(0xCC000000), Colors.transparent],
                              stops: [0, 0.55],
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                large ? 32 : 18, 0, 80, large ? 30 : 16),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                banner.title!,
                                maxLines: 2,
                                style: (large
                                        ? theme.textTheme.headlineSmall
                                        : theme.textTheme.titleMedium)
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (many && large) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _ArrowButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _go(_index - 1 + widget.banners.length),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _ArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _go(_index + 1)),
              ),
            ],
            if (many)
              Positioned(
                right: 18,
                bottom: 14,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.banners.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child:
            IconButton(onPressed: onTap, icon: Icon(icon, color: Colors.white)),
      ),
    );
  }
}

// ------------------------------------------------------------------ categories

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.categories});

  final List<catalog.Category> categories;

  static IconData iconFor(String slug) => switch (slug) {
        'mobile-games' => Icons.sports_esports_rounded,
        'gift-cards' => Icons.card_giftcard_rounded,
        'premium-apps' => Icons.workspace_premium_rounded,
        'vouchers' => Icons.confirmation_num_rounded,
        _ => Icons.category_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final wide = Breakpoints.isWide(context);

    Widget tile(catalog.Category category, int index) {
      final color = accentFor(index);
      return InkWell(
        onTap: () => context.go('/shop?category=${category.slug}'),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Ink(
          padding: EdgeInsets.all(wide ? 18 : 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: wide ? 46 : 38,
                height: wide ? 46 : 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconFor(category.slug),
                    color: color, size: wide ? 24 : 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: wide ? FlexFit.tight : FlexFit.loose,
                child: Text(
                  category.localisedName(strings.isBurmese),
                  maxLines: wide ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: (wide
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.labelLarge)
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!wide) {
      // Burmese category names wrap mid-word in narrow tiles, so phones get a
      // single scrolling row where every label stays on one line.
      return SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) => tile(categories[i], i),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * 3) / 4;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < categories.length; i++)
              SizedBox(width: width, child: tile(categories[i], i)),
          ],
        );
      },
    );
  }
}

// ----------------------------------------------------------------------- grids

class _GameGrid extends StatelessWidget {
  const _GameGrid({required this.products});

  final List<catalog.ProductSummary> products;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Fewer columns than a dense catalogue: the artwork is the selling
        // point, so each tile gets more room.
        final columns = width >= 1100
            ? 6
            : width >= 860
                ? 5
                : width >= 620
                    ? 4
                    : width >= 480
                        ? 3
                        : 2;
        final spacing = width >= 800 ? 18.0 : 12.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: GameCard.aspectRatio,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => GameCard(
            product: products[index],
            onTap: () => context.push('/product/${products[index].slug}'),
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------- recent orders

class _RecentOrders extends ConsumerWidget {
  const _RecentOrders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isSignedInProvider)) return const SizedBox.shrink();
    final orders =
        ref.watch(ordersProvider(null)).value?.items ?? const <Order>[];
    if (orders.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final wide = Breakpoints.isWide(context);
    final recent = orders.take(wide ? 3 : 2).toList();

    return Padding(
      padding: EdgeInsets.only(top: wide ? 40 : 24),
      child: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WebSectionTitle(
              title: strings.recentOrders,
              action: TextButton(
                  onPressed: () => context.go('/orders'),
                  child: Text(strings.viewAll)),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (final order in recent)
                      SizedBox(
                        width: width,
                        child: Card(
                          child: ListTile(
                            onTap: () => context.push('/orders/${order.id}'),
                            leading: AppImage(
                              url: order.items.isEmpty
                                  ? null
                                  : order.items.first.imageUrl,
                              width: 44,
                              height: 44,
                              fallbackIcon: Icons.receipt_long_rounded,
                            ),
                            title: Text(order.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${Format.money(order.total)} · ${Format.relative(order.createdAt)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: StatusChip(
                              label: OrderStatusUi.label(order.status, strings),
                              color: OrderStatusUi.color(order.status),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- trust + steps

class _MaintenanceBanner extends StatelessWidget {
  const _MaintenanceBanner({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.build_rounded, color: AppTheme.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: AppTheme.warning)),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(message, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    return ListView(
      children: [
        const SizedBox(height: 16),
        PageContainer(
            child:
                ShimmerBox(height: wide ? 340 : 170, radius: AppTheme.radius)),
        const SizedBox(height: 24),
        PageContainer(
          child: GridView.count(
            crossAxisCount: wide ? 6 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: GameCard.aspectRatio,
            children: List.generate(
                6, (_) => const ShimmerBox(radius: AppTheme.radius)),
          ),
        ),
      ],
    );
  }
}
