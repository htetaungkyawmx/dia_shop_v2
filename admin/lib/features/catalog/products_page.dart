import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/admin_catalog.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';
import '../stock/stock_sheet.dart';
import 'product_editor.dart';
import 'variant_editor.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  ProductFilter _filter = const ProductFilter();

  void _refresh() {
    ref.invalidate(productsProvider);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(_filter));
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          SearchField(
            hint: 'Product name or slug',
            onChanged: (value) => setState(
              () => _filter = ProductFilter(
                query: value,
                categoryId: _filter.categoryId,
                active: _filter.active,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () async {
              final list = categories.value ?? const <AdminCategory>[];
              if (list.isEmpty) {
                AdminSnack.info(context, 'Create a category first.');
                return;
              }
              final saved = await ProductEditor.show(context, categories: list);
              if (saved == true) _refresh();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New product'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: categories.when(
                    loading: () => const SizedBox(height: 34),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All categories'),
                          selected: _filter.categoryId == null,
                          onSelected: (_) => setState(
                            () => _filter = ProductFilter(
                                query: _filter.query, active: _filter.active),
                          ),
                        ),
                        for (final category in list)
                          ChoiceChip(
                            label: Text(category.name),
                            selected: _filter.categoryId == category.id,
                            onSelected: (_) => setState(
                              () => _filter = ProductFilter(
                                query: _filter.query,
                                categoryId: category.id,
                                active: _filter.active,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text('Hidden only'),
                  selected: _filter.active == false,
                  onSelected: (selected) => setState(
                    () => _filter = ProductFilter(
                      query: _filter.query,
                      categoryId: _filter.categoryId,
                      active: selected ? false : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncSection(
              value: products,
              onRetry: _refresh,
              loadingHeight: 420,
              builder: (page) {
                if (page.items.isEmpty) {
                  return const AdminEmpty(
                    icon: Icons.inventory_2_rounded,
                    title: 'No products',
                    message: 'Create your first product to start selling.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ProductCard(
                    product: page.items[index],
                    categories: categories.value ?? const [],
                    onChanged: _refresh,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.product,
    required this.categories,
    required this.onChanged,
  });

  final AdminProduct product;
  final List<AdminCategory> categories;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: product.imageUrl == null
              ? Container(
                  width: 46,
                  height: 46,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.sports_esports_rounded,
                      color: theme.colorScheme.onSurfaceVariant, size: 20),
                )
              : CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 46,
                    height: 46,
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(product.name, style: theme.textTheme.titleSmall)),
            const SizedBox(width: 10),
            if (!product.active) const StatusBadge(status: 'CANCELLED', label: 'Hidden'),
            if (product.featured) ...[
              const SizedBox(width: 6),
              const StatusBadge(status: 'COMPLETED', label: 'Featured'),
            ],
            if (product.lowStockCount > 0) ...[
              const SizedBox(width: 6),
              StatusBadge(status: 'PENDING', label: '${product.lowStockCount} low'),
            ],
          ],
        ),
        subtitle: Text(
          '${product.categoryName} · ${product.variants.length} package(s) · '
          '${prettyStatus(product.fulfillmentType)}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: () async {
                final saved =
                    await ProductEditor.show(context, product: product, categories: categories);
                if (saved == true) onChanged();
              },
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit'),
            ),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
        children: [
          Row(
            children: [
              Text('Packages', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final saved = await VariantEditor.show(context, productId: product.id);
                  if (saved == true) onChanged();
                },
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Add package'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (product.variants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No packages yet — add one so customers can buy.'),
            )
          else
            for (final variant in product.variants)
              _VariantRow(variant: variant, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _VariantRow extends ConsumerWidget {
  const _VariantRow({required this.variant, required this.onChanged});

  final AdminVariant variant;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stockColor = variant.isUnlimited
        ? theme.colorScheme.onSurfaceVariant
        : variant.available == 0
            ? AdminTheme.danger
            : variant.isLowStock
                ? AdminTheme.warning
                : AdminTheme.success;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(variant.name, style: theme.textTheme.bodyLarge)),
                    if (!variant.active) ...[
                      const SizedBox(width: 8),
                      const StatusBadge(status: 'CANCELLED', label: 'Hidden'),
                    ],
                  ],
                ),
                Text(
                  variant.sku,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Format.money(variant.price), style: theme.textTheme.titleSmall),
                Text(
                  'margin ${Format.money(variant.margin)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Icon(
                  variant.isUnlimited
                      ? Icons.all_inclusive_rounded
                      : variant.isCodePool
                          ? Icons.vpn_key_rounded
                          : Icons.inventory_2_outlined,
                  size: 16,
                  color: stockColor,
                ),
                const SizedBox(width: 6),
                Text(
                  variant.isUnlimited ? 'Unlimited' : '${variant.available} in stock',
                  style: theme.textTheme.bodySmall?.copyWith(color: stockColor),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Manage stock',
            onPressed: () => StockSheet.show(context, variant, onChanged),
            icon: const Icon(Icons.inventory_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Edit package',
            onPressed: () async {
              final saved = await VariantEditor.show(
                context,
                productId: variant.productId,
                variant: variant,
              );
              if (saved == true) onChanged();
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: variant.active ? 'Hide from shop' : 'Already hidden',
            onPressed: variant.active
                ? () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Hide package'),
                        content: Text(
                          '"${variant.name}" will stop appearing in the shop. '
                          'Past orders keep their history.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AdminTheme.danger),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Hide'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    try {
                      await ref.read(apiProvider).archiveVariant(variant.id);
                      onChanged();
                      if (context.mounted) AdminSnack.success(context, 'Package hidden');
                    } catch (error) {
                      if (context.mounted) AdminSnack.error(context, error);
                    }
                  }
                : null,
            icon: const Icon(Icons.visibility_off_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}
