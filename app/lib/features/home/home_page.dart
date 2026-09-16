import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/strings.dart';
import '../../models/catalog.dart' as catalog;
import '../../providers/providers.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/common.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final home = ref.watch(homeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeProvider);
            ref.invalidate(walletProvider);
            ref.invalidate(unreadCountProvider);
            await ref.read(homeProvider.future);
          },
          child: MaxWidthBody(
            maxWidth: 900,
            child: home.when(
              loading: () => const _HomeSkeleton(),
              error: (error, _) => ListView(
                children: [
                  const SizedBox(height: 120),
                  ErrorView(error: error, onRetry: () => ref.invalidate(homeProvider)),
                ],
              ),
              data: (data) => _HomeContent(data: data, strings: strings),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.data, required this.strings});

  final catalog.HomeData data;
  final Strings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final balance = ref.watch(walletProvider).value?.balance ?? user?.balance ?? 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _Greeting(name: user?.displayName, balance: balance),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _SearchBar(hint: strings.searchHint, onTap: () => context.push('/search')),
          ),
        ),
        if (data.maintenance)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _MaintenanceBanner(
                title: strings.maintenanceTitle,
                message: data.maintenanceMessage,
              ),
            ),
          ),
        if (data.banners.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: _BannerCarousel(banners: data.banners),
            ),
          ),
        if (data.categories.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
              child: SectionHeader(title: strings.categories),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: data.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = data.categories[index];
                  return CategoryPill(
                    label: category.localisedName(strings.isBurmese),
                    selected: false,
                    icon: _iconFor(category.slug),
                    onTap: () => context.push('/shop?category=${category.slug}'),
                  );
                },
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
            child: SectionHeader(
              title: strings.featured,
              actionLabel: strings.seeAll,
              onAction: () => context.push('/shop'),
            ),
          ),
        ),
        if (data.featured.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyView(
                icon: Icons.inventory_2_outlined,
                title: strings.noProducts,
                message: strings.noProductsBody,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // Image (1.35 ratio) plus two text lines.
                mainAxisExtent: 196,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = data.featured[index];
                  return ProductCard(
                    product: product,
                    onTap: () => context.push('/product/${product.slug}'),
                  );
                },
                childCount: data.featured.length,
              ),
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(String slug) => switch (slug) {
        'mobile-games' => Icons.sports_esports_rounded,
        'gift-cards' => Icons.card_giftcard_rounded,
        'premium-apps' => Icons.workspace_premium_rounded,
        'vouchers' => Icons.confirmation_num_rounded,
        _ => Icons.category_rounded,
      };
}

class _Greeting extends ConsumerWidget {
  const _Greeting({required this.name, required this.balance});

  final String? name;
  final int balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.isBurmese ? 'မင်္ဂလာပါ' : 'Hello',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              Text(
                name ?? strings.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
        BalancePill(balance: balance, onTap: () => context.push('/wallet/topup')),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: unread > 0
              ? Badge(
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications_none_rounded),
                )
              : const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(
              hint,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

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
                    style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.warning)),
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

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});

  final List<catalog.Banner> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_index + 1) % widget.banners.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _open(catalog.Banner banner) {
    switch (banner.linkType) {
      case 'PRODUCT':
        if (banner.linkValue != null) context.push('/product/${banner.linkValue}');
      case 'CATEGORY':
        if (banner.linkValue != null) context.push('/shop?category=${banner.linkValue}');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 156,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (index) => setState(() => _index = index),
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => _open(banner),
                  child: AppImage(
                    url: banner.imageUrl,
                    radius: AppTheme.radius,
                    fallbackIcon: Icons.campaign_rounded,
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ShimmerBox(height: 48),
        const SizedBox(height: 16),
        const ShimmerBox(height: 52),
        const SizedBox(height: 18),
        const ShimmerBox(height: 156, radius: AppTheme.radius),
        const SizedBox(height: 24),
        Row(
          children: List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(right: 8),
              child: ShimmerBox(width: 96, height: 40, radius: 999),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: List.generate(4, (_) => const ShimmerBox(radius: AppTheme.radius)),
        ),
      ],
    );
  }
}
