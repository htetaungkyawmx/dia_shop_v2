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

class ProductPage extends ConsumerWidget {
  const ProductPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(slug));

    return Scaffold(
      body: product.when(
        loading: () => const _ProductSkeleton(),
        error: (error, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(error: error, onRetry: () => ref.invalidate(productProvider(slug))),
        ),
        data: (detail) => _ProductBody(detail: detail),
      ),
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
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _checkout() {
    final strings = Strings.of(context);
    final variant = _selected;
    if (variant == null) return;
    if (!_formKey.currentState!.validate()) return;

    if (!ref.read(isSignedInProvider)) {
      context.push('/login');
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
            imageUrl: variant.imageUrl ?? widget.detail.imageUrl,
          ),
        );
    context.push('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final detail = widget.detail;
    final variant = _selected;
    final maxQuantity = variant?.maxPerOrder ?? 1;
    final total = (variant?.price ?? 0) * _quantity;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    url: detail.bannerUrl ?? detail.imageUrl,
                    radius: 0,
                    fallbackIcon: Icons.sports_esports_rounded,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          theme.scaffoldBackgroundColor,
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
            child: MaxWidthBody(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              detail.localisedName(strings.isBurmese),
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                          StatusChip(
                            label: detail.isInstantDelivery
                                ? strings.instantDelivery
                                : strings.manualDelivery,
                            color: detail.isInstantDelivery ? AppTheme.accent : AppTheme.info,
                            icon: detail.isInstantDelivery
                                ? Icons.bolt_rounded
                                : Icons.support_agent_rounded,
                          ),
                        ],
                      ),
                      if (detail.localisedDescription(strings.isBurmese) != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          detail.localisedDescription(strings.isBurmese)!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                      if (detail.fields.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        SectionHeader(title: strings.accountDetails),
                        const SizedBox(height: 10),
                        for (final field in detail.fields) ...[
                          _FieldInput(
                            field: field,
                            controller: _controllers[field.key]!,
                            burmese: strings.isBurmese,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                      const SizedBox(height: 14),
                      SectionHeader(title: strings.choosePackage),
                      const SizedBox(height: 10),
                      for (final v in detail.variants) ...[
                        VariantTile(
                          variant: v,
                          selected: _selected?.id == v.id,
                          onTap: () => setState(() {
                            _selected = v;
                            _quantity = 1;
                          }),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (variant != null && maxQuantity > 1) ...[
                        const SizedBox(height: 8),
                        _QuantityRow(
                          label: strings.quantity,
                          quantity: _quantity,
                          max: maxQuantity,
                          onChanged: (value) => setState(() => _quantity = value),
                        ),
                      ],
                      if (detail.localisedInstructions(strings.isBurmese) != null) ...[
                        const SizedBox(height: 22),
                        _InstructionsCard(
                          title: strings.howItWorks,
                          body: detail.localisedInstructions(strings.isBurmese)!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: variant == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: MaxWidthBody(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            strings.total,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            Format.money(total),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: variant.inStock ? _checkout : null,
                          icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                          label: Text(variant.inStock ? strings.buyNow : strings.outOfStock),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({required this.field, required this.controller, required this.burmese});

  final ProductField field;
  final TextEditingController controller;
  final bool burmese;

  @override
  Widget build(BuildContext context) {
    final label = field.localisedLabel(burmese);

    if (field.inputType == 'SELECT' && field.options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        decoration: InputDecoration(labelText: label, helperText: field.helpText),
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
              Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.primary),
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
