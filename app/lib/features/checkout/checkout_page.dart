import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _note = TextEditingController();
  OrderQuote? _quote;
  Object? _quoteError;
  bool _loadingQuote = true;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuote());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// The server prices the basket and checks stock, so the total shown here is
  /// the one that will actually be charged.
  Future<void> _loadQuote() async {
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) return;
    setState(() {
      _loadingQuote = true;
      _quoteError = null;
    });
    try {
      final quote = await ref.read(orderRepositoryProvider).quote(lines);
      if (mounted) setState(() => _quote = quote);
    } catch (error) {
      if (mounted) setState(() => _quoteError = error);
    } finally {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

  Future<void> _placeOrder() async {
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) return;
    setState(() => _placing = true);
    try {
      final order = await ref.read(orderRepositoryProvider).create(lines, note: _note.text.trim());
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(walletProvider);
      ref.invalidate(walletTransactionsProvider);
      ref.invalidate(ordersProvider);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(notificationsProvider);
      if (mounted) context.pushReplacement('/order-success/${order.id}');
    } catch (error) {
      if (!mounted) return;
      final failure = ApiException.from(error);
      AppSnack.error(context, failure);
      // Stock or price may have moved underneath us; re-quote so the screen
      // shows the current truth instead of a stale total.
      if (failure.isOutOfStock || failure.statusCode == 409) {
        await _loadQuote();
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final lines = ref.watch(cartProvider);

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.checkout)),
        body: EmptyView(
          icon: Icons.shopping_bag_outlined,
          title: strings.noProducts,
          action: FilledButton(
            onPressed: () => context.go('/shop'),
            child: Text(strings.keepShopping),
          ),
        ),
      );
    }

    final quote = _quote;

    return Scaffold(
      appBar: AppBar(title: Text(strings.checkout)),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeader(title: strings.orderSummary),
            const SizedBox(height: 10),
            for (final line in lines) ...[
              _CartLineCard(line: line),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: '${strings.noteToSeller} (${strings.optional})',
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingQuote)
              const ShimmerBox(height: 150, radius: AppTheme.radius)
            else if (_quoteError != null)
              ErrorView(error: _quoteError!, onRetry: _loadQuote, compact: true)
            else if (quote != null)
              _QuoteCard(quote: quote),
          ],
        ),
      ),
      bottomNavigationBar: quote == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: MaxWidthBody(
                  child: quote.affordable
                      ? FilledButton.icon(
                          onPressed: _placing ? null : _placeOrder,
                          icon: _placing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_rounded, size: 18),
                          label: Text('${strings.placeOrder} · ${Format.money(quote.total)}'),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              quote.shortfall > 0
                                  ? strings.shortfall(Format.money(quote.shortfall))
                                  : strings.outOfStock,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            if (quote.shortfall > 0)
                              FilledButton.icon(
                                onPressed: () => context.push('/wallet/topup'),
                                icon: const Icon(Icons.add_card_rounded, size: 18),
                                label: Text(strings.topUpNow),
                              ),
                          ],
                        ),
                ),
              ),
            ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(
              url: line.imageUrl,
              width: 52,
              height: 52,
              fallbackIcon: Icons.sports_esports_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.product, style: theme.textTheme.titleSmall),
                  Text(
                    '${line.variantName} × ${line.quantity}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (line.fieldValues.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final entry in line.fieldValues.entries)
                      Text(
                        '${_label(entry.key)}: ${entry.value}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ],
              ),
            ),
            Text(
              Format.money(line.lineTotal),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String key) => key
      .split('_')
      .map((part) => part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final OrderQuote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final line in quote.lines)
              if (!line.available && line.unavailableReason != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${line.variantName}: ${line.unavailableReason}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
            _Row(label: strings.subtotal, value: Format.money(quote.subtotal)),
            const SizedBox(height: 8),
            _Row(label: strings.walletBalance, value: Format.money(quote.walletBalance)),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            _Row(label: strings.total, value: Format.money(quote.total), emphasise: true),
            const SizedBox(height: 8),
            _Row(
              label: strings.balanceAfter,
              value: Format.money(quote.balanceAfter),
              valueColor: quote.balanceAfter < 0 ? theme.colorScheme.error : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasise;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasise ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: style?.copyWith(
                color: emphasise ? null : theme.colorScheme.onSurfaceVariant)),
        Text(value, style: style?.copyWith(color: valueColor, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
