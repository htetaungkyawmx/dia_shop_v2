import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../models/catalog.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/layout.dart';

class ProductPage extends ConsumerWidget {
  const ProductPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(slug));

    return product.when(
      loading: () => AppPage(
          body: const _ProductSkeleton(), maxWidth: Breakpoints.container),
      error: (error, _) => AppPage(
        title: '',
        body: ErrorView(
            error: error, onRetry: () => ref.invalidate(productProvider(slug))),
      ),
      data: (detail) => _ProductBody(detail: detail),
    );
  }
}

class _ProductBody extends ConsumerStatefulWidget {
  const _ProductBody({required this.detail});

  final ProductDetail detail;

  @override
  ConsumerState<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends ConsumerState<_ProductBody> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  ProductVariant? _selected;
  int? _popularId;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    for (final field in widget.detail.fields) {
      _controllers[field.key] = TextEditingController();
    }
    // Pre-select the most popular package that is actually in stock.
    final inStock = widget.detail.variants.where((v) => v.inStock).toList()
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
    _selected = inStock.isNotEmpty ? inStock.first : null;
    _popularId = inStock.length > 1 ? inStock.first.id : null;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Account details the buyer already used for this product, newest first,
  /// so a repeat top-up is one tap instead of retyping a Player ID.
  List<Map<String, String>> _savedDetails() {
    if (widget.detail.fields.isEmpty) return const [];
    final orders =
        ref.watch(ordersProvider(null)).value?.items ?? const <Order>[];
    final seen = <String>{};
    final result = <Map<String, String>>[];
    for (final order in orders) {
      for (final item in order.items) {
        if (item.productName != widget.detail.name ||
            item.fieldValues.isEmpty) {
          continue;
        }
        final key = item.fieldValues.entries
            .map((e) => '${e.key}=${e.value}')
            .join('|');
        if (seen.add(key)) result.add(item.fieldValues);
      }
    }
    return result.take(4).toList();
  }

  void _applySaved(Map<String, String> values) {
    setState(() {
      values.forEach((key, value) => _controllers[key]?.text = value);
    });
  }

  void _checkout() {
    final strings = Strings.of(context);
    final variant = _selected;
    if (variant == null) return;
    if (!_formKey.currentState!.validate()) return;

    if (!ref.read(isSignedInProvider)) {
      pushLogin(context);
      return;
    }

    final values = <String, String>{};
    for (final field in widget.detail.fields) {
      final text = _controllers[field.key]!.text.trim();
      if (text.isNotEmpty) values[field.key] = text;
    }

    ref.read(cartProvider.notifier).replaceWith(
          CartLine(
            product: widget.detail.localisedName(strings.isBurmese),
            variantId: variant.id,
            variantName: variant.localisedName(strings.isBurmese),
            unitPrice: variant.price,
            quantity: _quantity,
            fieldValues: values,
            imageUrl: widget.detail.imageUrl ?? variant.imageUrl,
          ),
        );
    context.push('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    return Breakpoints.isWide(context)
        ? _buildWide(context)
        : _buildCompact(context);
  }

  // ------------------------------------------------------------- sections

  Widget _titleBlock(BuildContext context, {required bool onImage}) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final detail = widget.detail;
    final color = onImage ? Colors.white : theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusChip(
          label: detail.isInstantDelivery
              ? strings.instantDelivery
              : strings.manualDelivery,
          color: detail.isInstantDelivery ? AppTheme.accent : AppTheme.info,
          icon: detail.isInstantDelivery
              ? Icons.bolt_rounded
              : Icons.support_agent_rounded,
        ),
        const SizedBox(height: 10),
        Text(
          detail.localisedName(strings.isBurmese),
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w800),
        ),
        if (detail.localisedDescription(strings.isBurmese) != null) ...[
          const SizedBox(height: 6),
          Text(
            detail.localisedDescription(strings.isBurmese)!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  onImage ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _fieldsSection(BuildContext context) {
    final strings = Strings.of(context);
    final saved = _savedDetails();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: strings.accountDetails),
        if (saved.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(strings.savedIds, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final values in saved)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  label: Text(values.values.join(' · ')),
                  onPressed: () => _applySaved(values),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        for (final field in widget.detail.fields) ...[
          _FieldInput(
              field: field,
              controller: _controllers[field.key]!,
              burmese: strings.isBurmese),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _packagesSection(BuildContext context, {required int columns}) {
    final strings = Strings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: strings.choosePackage),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final v in widget.detail.variants)
                  SizedBox(
                    width: width,
                    child: VariantTile(
                      variant: v,
                      popular: v.id == _popularId,
                      selected: _selected?.id == v.id,
                      onTap: () => setState(() {
                        _selected = v;
                        _quantity = 1;
                      }),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget? _quantitySection(BuildContext context) {
    final variant = _selected;
    if (variant == null || variant.maxPerOrder <= 1) return null;
    return _QuantityRow(
      label: Strings.of(context).quantity,
      quantity: _quantity,
      max: variant.maxPerOrder,
      onChanged: (value) => setState(() => _quantity = value),
    );
  }

  Widget? _instructionsSection(BuildContext context) {
    final strings = Strings.of(context);
    final text = widget.detail.localisedInstructions(strings.isBurmese);
    return text == null
        ? null
        : _InstructionsCard(title: strings.howItWorks, body: text);
  }

  Widget _buyButton(BuildContext context) {
    final strings = Strings.of(context);
    final variant = _selected;
    return FilledButton.icon(
      onPressed: variant != null && variant.inStock ? _checkout : null,
      icon: const Icon(Icons.shopping_bag_rounded, size: 18),
      label: Text(variant == null || variant.inStock
          ? strings.buyNow
          : strings.outOfStock),
    );
  }

  // --------------------------------------------------------------- layouts

  Widget _buildWide(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final detail = widget.detail;
    final quantity = _quantitySection(context);
    final instructions = _instructionsSection(context);
    final total = (_selected?.price ?? 0) * _quantity;

    final summaryPanel = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detail.fields.isNotEmpty) _fieldsSection(context),
          if (_selected != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selected!.localisedName(strings.isBurmese),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(Format.money(_selected!.price),
                    style: theme.textTheme.titleSmall),
              ],
            ),
          ],
          if (quantity != null) ...[const SizedBox(height: 12), quantity],
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                  child:
                      Text(strings.total, style: theme.textTheme.titleMedium)),
              Text(
                Format.money(total),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buyButton(context),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.verified_user_rounded,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.featureSecureBody,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return AppPage(
      maxWidth: Breakpoints.container,
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            PageContainer(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius),
                            child: SizedBox(
                              height: 300,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _HeroBackground(detail: detail),
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Color(0xE0000000)
                                        ],
                                        stops: [0.3, 1],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 24,
                                    right: 24,
                                    bottom: 22,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (detail.imageUrl != null) ...[
                                          AppImage(
                                              url: detail.imageUrl,
                                              width: 96,
                                              height: 132,
                                              radius: 14),
                                          const SizedBox(width: 18),
                                        ],
                                        Expanded(
                                            child: _titleBlock(context,
                                                onImage: true)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _packagesSection(context, columns: 2),
                          if (instructions != null) ...[
                            const SizedBox(height: 24),
                            instructions
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    SizedBox(width: 380, child: summaryPanel),
                  ],
                ),
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final detail = widget.detail;
    final quantity = _quantitySection(context);
    final instructions = _instructionsSection(context);
    final total = (_selected?.price ?? 0) * _quantity;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _HeroBackground(detail: detail),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          theme.scaffoldBackgroundColor
                        ],
                        stops: const [0, 0.5, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _titleBlock(context, onImage: false),
                    if (detail.fields.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _fieldsSection(context)
                    ],
                    const SizedBox(height: 12),
                    _packagesSection(context,
                        columns:
                            MediaQuery.sizeOf(context).width >= 600 ? 2 : 1),
                    if (quantity != null) ...[
                      const SizedBox(height: 16),
                      quantity
                    ],
                    if (instructions != null) ...[
                      const SizedBox(height: 22),
                      instructions
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.total,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          Format.money(total),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buyButton(context)),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Wide header art. Products without a banner only have a small portrait card
/// image, which looks smeared when stretched across a hero, so that case is
/// blurred into a colour wash instead.
class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.detail});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.bannerUrl != null) {
      return AppImage(
          url: detail.bannerUrl,
          radius: 0,
          fallbackIcon: Icons.sports_esports_rounded);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.brandGradientDark)),
        if (detail.imageUrl != null)
          Opacity(
            opacity: 0.55,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                  sigmaX: 28, sigmaY: 28, tileMode: TileMode.decal),
              child: AppImage(url: detail.imageUrl, radius: 0),
            ),
          ),
      ],
    );
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput(
      {required this.field, required this.controller, required this.burmese});

  final ProductField field;
  final TextEditingController controller;
  final bool burmese;

  @override
  Widget build(BuildContext context) {
    final label = field.localisedLabel(burmese);

    if (field.inputType == 'SELECT' && field.options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        decoration:
            InputDecoration(labelText: label, helperText: field.helpText),
        items: [
          for (final option in field.options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) => controller.text = value ?? '',
        validator: (value) => field.validate(value, burmese),
      );
    }

    return TextFormField(
      controller: controller,
      keyboardType: switch (field.inputType) {
        'NUMBER' => TextInputType.number,
        'EMAIL' => TextInputType.emailAddress,
        _ => TextInputType.text,
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: field.placeholder,
        helperText: field.helpText,
      ),
      validator: (value) => field.validate(value, burmese),
    );
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.label,
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
        IconButton.filledTonal(
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ShimmerBox(height: 210, radius: 0),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBox(height: 28, width: 220),
              const SizedBox(height: 12),
              const ShimmerBox(height: 16),
              const SizedBox(height: 24),
              ...List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: ShimmerBox(height: 72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
