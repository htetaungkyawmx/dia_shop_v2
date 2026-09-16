import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/strings.dart';
import '../../models/catalog.dart';
import '../../providers/providers.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/layout.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void didUpdateWidget(ShopPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shop tab stays alive between visits, so a new ?category= link
    // (from a banner, footer or home tile) arrives as an update, not a rebuild.
    if (widget.initialCategory != oldWidget.initialCategory) {
      _category = widget.initialCategory;
    }
  }

  void _select(String? slug) {
    setState(() => _category = slug);
    context.go(slug == null ? '/shop' : '/shop?category=$slug');
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final wide = Breakpoints.isWide(context);
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final query = ProductQuery(category: _category);
    final products = ref.watch(productsProvider(query));

    final grid = products.when(
      loading: () => const _GridSkeleton(),
      error: (error, _) => ErrorView(
          error: error, onRetry: () => ref.invalidate(productsProvider(query))),
      data: (list) => list.isEmpty
          ? EmptyView(
              icon: Icons.inventory_2_outlined,
              title: strings.noProducts,
              message: strings.noProductsBody)
          : _ProductGrid(products: list),
    );

    final current = categories.where((c) => c.slug == _category).firstOrNull;
    final heading = current?.localisedName(strings.isBurmese) ?? strings.shop;

    if (wide) {
      return Scaffold(
        body: Column(
          children: [
            const WebHeader(),
            Expanded(
              child: ListView(
                children: [
                  PageContainer(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 240,
                            child: _CategoryMenu(
                                categories: categories,
                                selected: _category,
                                onSelect: _select),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                WebSectionTitle(
                                  title: heading,
                                  action: IconButton.filledTonal(
                                    tooltip: strings.search,
                                    onPressed: () => context.push('/search'),
                                    icon: const Icon(Icons.search_rounded),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                grid,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SiteFooter(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(heading),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
            tooltip: strings.search,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productsProvider(query));
          await ref.read(productsProvider(query).future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: [
                  CategoryPill(
                      label: strings.allOrders,
                      selected: _category == null,
                      onTap: () => _select(null)),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: CategoryPill(
                        label: c.localisedName(strings.isBurmese),
                        selected: _category == c.slug,
                        onTap: () => _select(c.slug),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: grid),
          ],
        ),
      ),
    );
  }
}

class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu(
      {required this.categories,
      required this.selected,
      required this.onSelect});

  final List<Category> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    Widget entry(String label, String? slug, IconData icon) {
      final active = selected == slug;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            dense: true,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(icon,
                size: 20, color: active ? theme.colorScheme.primary : null),
            title: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: active ? theme.colorScheme.primary : null,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            onTap: () => onSelect(slug),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Text(strings.categories, style: theme.textTheme.labelLarge),
          ),
          entry(strings.allOrders, null, Icons.apps_rounded),
          for (final c in categories)
            entry(
              c.localisedName(strings.isBurmese),
              c.slug,
              switch (c.slug) {
                'mobile-games' => Icons.sports_esports_rounded,
                'gift-cards' => Icons.card_giftcard_rounded,
                'premium-apps' => Icons.workspace_premium_rounded,
                'vouchers' => Icons.confirmation_num_rounded,
                _ => Icons.category_rounded,
              },
            ),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<ProductSummary> products;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 5
            : width >= 700
                ? 4
                : width >= 480
                    ? 3
                    : 2;
        final spacing = width >= 700 ? 18.0 : 12.0;
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

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 5 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: GameCard.aspectRatio,
          children: List.generate(
              columns * 2, (_) => const ShimmerBox(radius: AppTheme.radius)),
        );
      },
    );
  }
}
