import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/admin_catalog.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';

/// Everything about one package's stock: adjust, recount, upload codes and the
/// full movement history — all against the endpoints that keep an audit trail.
class StockSheet extends ConsumerStatefulWidget {
  const StockSheet({super.key, required this.variant, required this.onChanged});

  final AdminVariant variant;
  final VoidCallback onChanged;

  static Future<void> show(
      BuildContext context, AdminVariant variant, VoidCallback onChanged) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: StockSheet(variant: variant, onChanged: onChanged),
        ),
      ),
    );
  }

  @override
  ConsumerState<StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends ConsumerState<StockSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late AdminVariant _variant = widget.variant;

  /// Tracked separately so a code upload can update the count without having
  /// to rebuild a whole AdminVariant from a partial response.
  late int _available = widget.variant.available;
  bool _busy = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _afterChange(AdminVariant updated) {
    setState(() {
      _variant = updated;
      _available = updated.available;
    });
    ref.invalidate(stockMovementsProvider(_variant.id));
    ref.invalidate(stockCodesProvider(_variant.id));
    ref.invalidate(dashboardProvider);
    widget.onChanged();
  }

  Future<void> _adjust(int delta, String reason) async {
    final note = await promptForNote(
      context,
      title: delta > 0 ? 'Add stock' : 'Remove stock',
      message: delta > 0
          ? 'Add $delta unit(s) to "${_variant.name}".'
          : 'Remove ${-delta} unit(s) from "${_variant.name}".',
      confirmLabel: 'Apply',
      noteLabel: 'Why (kept in the stock history)',
      noteRequired: true,
    );
    if (note == null) return;

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(apiProvider)
          .adjustStock(_variant.id, delta: delta, reason: reason, note: note);
      _afterChange(updated);
      if (mounted) {
        AdminSnack.success(context, 'Stock is now ${updated.available}');
      }
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _customAdjust() async {
    final controller = TextEditingController();
    String reason = 'RESTOCK';

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust stock'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Current stock: $_available'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Change',
                    helperText: 'Use a negative number to remove, e.g. -3',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(value: 'RESTOCK', child: Text('Restock')),
                    DropdownMenuItem(
                        value: 'MANUAL_ADJUST', child: Text('Manual adjust')),
                    DropdownMenuItem(
                        value: 'DAMAGE', child: Text('Damaged / lost')),
                    DropdownMenuItem(
                        value: 'CORRECTION', child: Text('Correction')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => reason = value ?? 'RESTOCK'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final delta = int.tryParse(controller.text.trim());
                if (delta == null || delta == 0) return;
                Navigator.pop(context, delta);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    final delta = result;
    controller.dispose();
    if (delta != null) await _adjust(delta, reason);
  }

  Future<void> _recount() async {
    final controller = TextEditingController(text: '$_available');
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set exact stock'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Stock on hand',
              helperText: 'The difference is recorded as a correction',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0) return;
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null) return;

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(apiProvider)
          .setStock(_variant.id, quantity: quantity, note: 'Recount by staff');
      _afterChange(updated);
      if (mounted) AdminSnack.success(context, 'Stock set to $quantity');
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCodes() async {
    final codesController = TextEditingController();
    final secretController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add codes'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'Paste one code per line. Duplicates are skipped automatically.'),
              const SizedBox(height: 14),
              TextField(
                controller: codesController,
                autofocus: true,
                maxLines: 9,
                minLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Codes',
                  hintText: 'ABCD-1234-EFGH\nIJKL-5678-MNOP',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretController,
                decoration: const InputDecoration(
                  labelText: 'Shared PIN (optional)',
                  helperText: 'Applied to every code in this batch',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add to stock'),
          ),
        ],
      ),
    );

    final codes = codesController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final secret = secretController.text.trim();
    codesController.dispose();
    secretController.dispose();

    if (confirmed != true || codes.isEmpty) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(apiProvider)
          .addStockCodes(_variant.id, codes, secret: secret);
      ref.invalidate(stockCodesProvider(_variant.id));
      ref.invalidate(stockMovementsProvider(_variant.id));
      ref.invalidate(dashboardProvider);
      widget.onChanged();
      setState(() => _available = result['availableNow'] ?? _available);
      if (mounted) {
        AdminSnack.success(
          context,
          '${result['added']} code(s) added'
          '${result['skippedDuplicates']! > 0 ? ', ${result['skippedDuplicates']} duplicate(s) skipped' : ''}',
        );
      }
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_variant.productName} · ${_variant.name}',
                        style: theme.textTheme.titleLarge),
                    Text(
                      '${_variant.sku} · ${prettyStatus(_variant.stockType)} stock',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: _StockSummary(variant: _variant, available: _available),
              ),
              const SizedBox(width: 20),
              if (_busy)
                const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (_variant.isUnlimited)
                Text(
                  'Unlimited stock — nothing to manage.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else if (_variant.isCodePool)
                FilledButton.icon(
                  onPressed: _addCodes,
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: const Text('Add codes'),
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Remove one',
                      onPressed: () => _adjust(-1, 'MANUAL_ADJUST'),
                      icon: const Icon(Icons.remove_rounded, size: 18),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Add one',
                      onPressed: () => _adjust(1, 'RESTOCK'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                    ),
                    OutlinedButton(
                        onPressed: _customAdjust, child: const Text('Adjust…')),
                    OutlinedButton(
                        onPressed: _recount, child: const Text('Recount')),
                  ],
                ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'History'), Tab(text: 'Codes')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _MovementList(variantId: _variant.id),
              _variant.isCodePool
                  ? _CodeList(variantId: _variant.id)
                  : const AdminEmpty(
                      icon: Icons.vpn_key_off_rounded,
                      title: 'Not a code pool',
                      message:
                          'Switch this package to Code pool stock to store keys here.',
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockSummary extends StatelessWidget {
  const _StockSummary({required this.variant, required this.available});

  final AdminVariant variant;
  final int available;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlimited = variant.isUnlimited;
    final color = unlimited
        ? AdminTheme.info
        : available == 0
            ? AdminTheme.danger
            : available <= variant.lowStockThreshold
                ? AdminTheme.warning
                : AdminTheme.success;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            unlimited ? Icons.all_inclusive_rounded : Icons.inventory_2_rounded,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              unlimited ? 'Unlimited' : '$available',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              unlimited
                  ? 'Fulfilled by hand, never runs out'
                  : 'in stock · alert below ${variant.lowStockThreshold}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class _MovementList extends ConsumerWidget {
  const _MovementList({required this.variantId});

  final int variantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final movements = ref.watch(stockMovementsProvider(variantId));

    return AsyncSection(
      value: movements,
      onRetry: () => ref.invalidate(stockMovementsProvider(variantId)),
      builder: (page) {
        if (page.items.isEmpty) {
          return const AdminEmpty(
              icon: Icons.history_rounded, title: 'No stock changes yet');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: page.items.length,
          separatorBuilder: (_, __) => const Divider(height: 18),
          itemBuilder: (context, index) {
            final move = page.items[index];
            final positive = move.delta > 0;
            return Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    '${positive ? '+' : ''}${move.delta}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: positive ? AdminTheme.success : AdminTheme.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${prettyStatus(move.reason)} · ${move.actor}',
                          style: theme.textTheme.bodyMedium),
                      if ((move.note ?? '').isNotEmpty)
                        Text(
                          move.note!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${move.quantityBefore} → ${move.quantityAfter}',
                        style: theme.textTheme.bodyMedium),
                    Text(
                      Format.dateTime(move.createdAt),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CodeList extends ConsumerWidget {
  const _CodeList({required this.variantId});

  final int variantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final codes = ref.watch(stockCodesProvider(variantId));

    return AsyncSection(
      value: codes,
      onRetry: () => ref.invalidate(stockCodesProvider(variantId)),
      builder: (page) {
        if (page.items.isEmpty) {
          return const AdminEmpty(
            icon: Icons.vpn_key_rounded,
            title: 'No codes yet',
            message: 'Use "Add codes" above to load your keys.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: page.items.length,
          separatorBuilder: (_, __) => const Divider(height: 16),
          itemBuilder: (context, index) {
            final code = page.items[index];
            return Row(
              children: [
                // Only the masked tail is ever shown here: a sold code belongs
                // to the buyer, and an unsold one should not leak from a screen.
                Expanded(
                  child: Text(code.codeMasked,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(letterSpacing: 1.1)),
                ),
                StatusBadge(
                  status: switch (code.status) {
                    'AVAILABLE' => 'ACTIVE',
                    'SOLD' => 'COMPLETED',
                    'VOID' => 'CANCELLED',
                    _ => 'PENDING',
                  },
                  label: prettyStatus(code.status),
                ),
                const SizedBox(width: 16),
                Text(
                  Format.date(code.assignedAt ?? code.createdAt),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
