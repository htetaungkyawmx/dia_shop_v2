import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';
import '../l10n/strings.dart';
import '../models/catalog.dart';
import 'common.dart';

/// Tile used on the home grid and category lists.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final ProductSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The image takes whatever height the text leaves. A fixed aspect
            // ratio overflowed the grid cell as soon as a name wrapped, and
            // Burmese script needs more line height than Latin.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    url: product.imageUrl,
                    radius: AppTheme.radius,
                    fallbackIcon: Icons.sports_esports_rounded,
                  ),
                  if (!product.inStock)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                        ),
                        child: Center(
                          child: StatusChip(
                              label: strings.outOfStock, color: Colors.white),
                        ),
                      ),
                    ),
                  if (product.fulfillmentType == 'CODE_DELIVERY' &&
                      product.inStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: StatusChip(
                        label: strings.instantDelivery,
                        color: AppTheme.accent,
                        icon: Icons.bolt_rounded,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.localisedName(strings.isBurmese),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  if (product.startingPrice != null)
                    Text(
                      '${strings.priceFrom} ${Format.money(product.startingPrice!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      '—',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

class CategoryPill extends StatelessWidget {
  const CategoryPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.brandGradient : null,
          color: selected ? null : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? Colors.transparent : theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : theme.colorScheme.onSurface),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable package row on the product page.
class VariantTile extends StatelessWidget {
  const VariantTile({
    super.key,
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final ProductVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final enabled = variant.inStock;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.10)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.diamond_rounded,
                    color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.localisedName(strings.isBurmese),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (variant.bonusText != null ||
                        variant.isLowStock ||
                        !enabled) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (variant.bonusText != null)
                            StatusChip(
                                label: variant.bonusText!,
                                color: AppTheme.success),
                          if (enabled && variant.isLowStock)
                            StatusChip(
                              label: strings.lowStock(variant.remaining!),
                              color: AppTheme.warning,
                            ),
                          if (!enabled)
                            StatusChip(
                                label: strings.outOfStock,
                                color: AppTheme.danger),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (variant.isOnSale)
                    Text(
                      Format.money(variant.compareAtPrice!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    Format.money(variant.price),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (variant.isOnSale)
                    Text(
                      '-${variant.discountPercent}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wallet balance pill shown in app bars.
class BalancePill extends StatelessWidget {
  const BalancePill({super.key, required this.balance, this.onTap});

  final int balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient, shape: BoxShape.circle),
              child: const Icon(Icons.currency_exchange_rounded,
                  size: 12, color: Colors.white),
            ),
            const SizedBox(width: 7),
            Text(
              Format.number(balance),
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
