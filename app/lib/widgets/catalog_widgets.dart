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
    this.popular = false,
  });

  final ProductVariant variant;
  final bool selected;
  final VoidCallback onTap;

  /// Marks the best-selling package so first-time buyers have a default.
  final bool popular;

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
                    if (popular ||
                        variant.bonusText != null ||
                        variant.isLowStock ||
                        !enabled) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (popular && enabled)
                            StatusChip(
                              label: strings.popularBadge,
                              color: AppTheme.gold,
                              icon: Icons.local_fire_department_rounded,
                            ),
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

/// Portrait game card, styled after store key art: the name and starting price
/// sit over a darkened bottom edge of the image, so the card height is fixed
/// by its aspect ratio and can never overflow however long the name is.
class GameCard extends StatefulWidget {
  const GameCard({super.key, required this.product, required this.onTap});

  static const double aspectRatio = 0.72;

  final ProductSummary product;
  final VoidCallback onTap;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final product = widget.product;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 160),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                    color: AppTheme.brand.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest,
              child: InkWell(
                onTap: widget.onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (product.imageUrl != null)
                      AppImage(
                          url: product.imageUrl,
                          radius: 0,
                          fallbackIcon: Icons.sports_esports_rounded)
                    else
                      _ArtPlaceholder(
                          name: product.localisedName(strings.isBurmese)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Color(0xE6000000)
                          ],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (product.inStock &&
                              product.fulfillmentType == 'CODE_DELIVERY')
                            _Pill(
                                icon: Icons.bolt_rounded,
                                label: strings.instantDelivery,
                                color: AppTheme.accent),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.localisedName(strings.isBurmese),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            !product.inStock
                                ? strings.outOfStock
                                : product.startingPrice == null
                                    ? ''
                                    : '${strings.priceFrom} ${Format.money(product.startingPrice!)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: product.inStock
                                  ? AppTheme.gold
                                  : const Color(0xFFFF8A80),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Branded stand-in for products that have no artwork uploaded yet.
class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    // Pick a stable gradient per product so a row of placeholders still varies.
    const palettes = [
      [Color(0xFF6C5CE7), Color(0xFF2D1E8F)],
      [Color(0xFF0EA5E9), Color(0xFF1E3A8A)],
      [Color(0xFFF59E0B), Color(0xFF9A3412)],
      [Color(0xFF10B981), Color(0xFF065F46)],
      [Color(0xFFEC4899), Color(0xFF7E1D5E)],
    ];
    final colors = palettes[
        name.codeUnits.fold<int>(0, (a, b) => a + b) % palettes.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Align(
        alignment: const Alignment(0, -0.25),
        child: Icon(Icons.sports_esports_rounded,
            size: 56, color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }
}
