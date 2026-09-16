import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/common.dart';

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
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productsProvider(ProductQuery(category: _category)));

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.shop),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
            tooltip: strings.search,
          ),
        ],
      ),
      body: MaxWidthBody(
        maxWidth: 900,
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: categories.when(
                loading: () => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  children: List.generate(
                    4,
                    (_) => const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: ShimmerBox(width: 96, height: 40, radius: 999),
                    ),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return CategoryPill(
                        label: strings.allOrders,
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      );
                    }
                    final category = list[index - 1];
                    return CategoryPill(
                      label: category.localisedName(strings.isBurmese),
                      selected: _category == category.slug,
                      onTap: () => setState(() => _category = category.slug),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: products.when(
                loading: () => GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                  children: List.generate(6, (_) => const ShimmerBox(radius: 18)),
                ),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(productsProvider(ProductQuery(category: _category))),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyView(
                      icon: Icons.inventory_2_outlined,
                      title: strings.noProducts,
                      message: strings.noProductsBody,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(productsProvider(ProductQuery(category: _category)));
                      await ref
                          .read(productsProvider(ProductQuery(category: _category)).future);
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 196,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, index) => ProductCard(
                        product: list[index],
                        onTap: () => context.push('/product/${list[index].slug}'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
