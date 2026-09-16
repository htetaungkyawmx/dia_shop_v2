import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin_catalog.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';

/// Create or edit a package. Stock is deliberately not editable here — it moves
/// only through the stock endpoints so every change keeps an audit trail.
class VariantEditor extends ConsumerStatefulWidget {
  const VariantEditor({super.key, required this.productId, this.variant});

  final int productId;
  final AdminVariant? variant;

  static Future<bool?> show(BuildContext context,
      {required int productId, AdminVariant? variant}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
          child: VariantEditor(productId: productId, variant: variant),
        ),
      ),
    );
  }

  @override
  ConsumerState<VariantEditor> createState() => _VariantEditorState();
}

class _VariantEditorState extends ConsumerState<VariantEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sku;
  late final TextEditingController _name;
  late final TextEditingController _nameMy;
  late final TextEditingController _bonus;
  late final TextEditingController _price;
  late final TextEditingController _compareAt;
  late final TextEditingController _cost;
  late final TextEditingController _threshold;
  late final TextEditingController _maxPerOrder;
  late final TextEditingController _popularity;
  late final TextEditingController _sortOrder;
  late final TextEditingController _initialStock;
  late final TextEditingController _supplierProductId;

  late String _stockType;
  late String _supplier; // 'NONE' or 'SMILEONE'
  late bool _active;
  bool _busy = false;

  bool get _isNew => widget.variant == null;

  @override
  void initState() {
    super.initState();
    final v = widget.variant;
    _sku = TextEditingController(text: v?.sku ?? '');
    _name = TextEditingController(text: v?.name ?? '');
    _nameMy = TextEditingController(text: v?.nameMy ?? '');
    _bonus = TextEditingController(text: v?.bonusText ?? '');
    _price = TextEditingController(text: '${v?.price ?? ''}');
    _compareAt = TextEditingController(
        text: v?.compareAtPrice == null ? '' : '${v!.compareAtPrice}');
    _cost = TextEditingController(text: '${v?.costPrice ?? 0}');
    _threshold = TextEditingController(text: '${v?.lowStockThreshold ?? 5}');
    _maxPerOrder = TextEditingController(text: '${v?.maxPerOrder ?? 10}');
    _popularity = TextEditingController(text: '${v?.popularity ?? 0}');
    _sortOrder = TextEditingController(text: '${v?.sortOrder ?? 0}');
    _initialStock = TextEditingController(text: '${v?.stockQuantity ?? 0}');
    _supplierProductId =
        TextEditingController(text: v?.supplierProductId ?? '');
    _stockType = v?.stockType ?? 'UNLIMITED';
    _supplier = (v?.supplier == null || v!.supplier!.isEmpty)
        ? 'NONE'
        : v.supplier!;
    _active = v?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _sku,
      _name,
      _nameMy,
      _bonus,
      _price,
      _compareAt,
      _cost,
      _threshold,
      _maxPerOrder,
      _popularity,
      _sortOrder,
      _initialStock,
      _supplierProductId,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final body = <String, dynamic>{
      'sku': _sku.text.trim(),
      'name': _name.text.trim(),
      'nameMy': _nameMy.text.trim().isEmpty ? null : _nameMy.text.trim(),
      'bonusText': _bonus.text.trim().isEmpty ? null : _bonus.text.trim(),
      'price': int.parse(_price.text.trim()),
      'compareAtPrice': _compareAt.text.trim().isEmpty
          ? null
          : int.parse(_compareAt.text.trim()),
      'costPrice': int.tryParse(_cost.text.trim()) ?? 0,
      'stockType': _stockType,
      'stockQuantity': int.tryParse(_initialStock.text.trim()) ?? 0,
      'lowStockThreshold': int.tryParse(_threshold.text.trim()) ?? 5,
      'maxPerOrder': int.tryParse(_maxPerOrder.text.trim()) ?? 10,
      'popularity': int.tryParse(_popularity.text.trim()) ?? 0,
      'sortOrder': int.tryParse(_sortOrder.text.trim()) ?? 0,
      'active': _active,
      'supplier': _supplier == 'NONE' ? null : _supplier,
      'supplierProductId': _supplier == 'NONE' || _supplierProductId.text.trim().isEmpty
          ? null
          : _supplierProductId.text.trim(),
    };

    try {
      await ref.read(apiProvider).saveVariant(
            body,
            productId: _isNew ? widget.productId : null,
            variantId: widget.variant?.id,
          );
      if (mounted) {
        AdminSnack.success(
            context, _isNew ? 'Package created' : 'Package updated');
        Navigator.pop(context, true);
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
    // The counter is only meaningful for a brand-new LIMITED package; after
    // that it is owned by the stock endpoints.
    final showInitialStock = _stockType == 'LIMITED' &&
        (_isNew || widget.variant?.stockType != 'LIMITED');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(_isNew ? 'New package' : 'Edit package',
                    style: theme.textTheme.titleLarge),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: '86 Diamonds',
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _sku,
                        decoration: const InputDecoration(
                          labelText: 'SKU',
                          hintText: 'MLBB-86',
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameMy,
                        decoration: const InputDecoration(
                            labelText: 'Burmese name (optional)'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _bonus,
                        decoration: const InputDecoration(
                          labelText: 'Badge (optional)',
                          hintText: '+8 Bonus',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Pricing', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _moneyField(_price, 'Selling price',
                            required: true)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _moneyField(_compareAt, 'Was price (optional)'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _moneyField(_cost, 'Cost price'),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Cost price is never shown to customers; it drives the profit report.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Stock', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _stockType,
                  decoration: const InputDecoration(labelText: 'Stock type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'UNLIMITED',
                      child: Text('Unlimited — top-ups done by hand'),
                    ),
                    DropdownMenuItem(
                      value: 'LIMITED',
                      child: Text('Limited — counted stock, e.g. accounts'),
                    ),
                    DropdownMenuItem(
                      value: 'CODE_POOL',
                      child: Text(
                          'Code pool — pre-loaded keys, delivered instantly'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _stockType = value ?? 'UNLIMITED'),
                ),
                if (showInitialStock) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _initialStock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration:
                        const InputDecoration(labelText: 'Starting stock'),
                  ),
                ],
                if (!_isNew && !showInitialStock && _stockType != 'UNLIMITED')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Change the stock level from the stock screen so the history stays complete.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _numberField(_threshold, 'Low stock alert at')),
                    const SizedBox(width: 14),
                    Expanded(
                        child: _numberField(_maxPerOrder, 'Max per order')),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Auto delivery', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _supplier,
                  decoration:
                      const InputDecoration(labelText: 'Delivered by'),
                  items: const [
                    DropdownMenuItem(
                      value: 'NONE',
                      child: Text('Manual — filled by staff'),
                    ),
                    DropdownMenuItem(
                      value: 'SMILEONE',
                      child: Text('Smile.one — delivered automatically'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _supplier = value ?? 'NONE'),
                ),
                if (_supplier == 'SMILEONE') ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _supplierProductId,
                    decoration: const InputDecoration(
                      labelText: 'Smile.one product id',
                      hintText: 'e.g. 13 (from the Smile.one price list)',
                    ),
                    validator: (v) => _supplier == 'SMILEONE' &&
                            (v ?? '').trim().isEmpty
                        ? 'Enter the Smile.one product id, or set Manual'
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Set the game on the product itself (Smile.one game code). '
                      'Auto delivery must also be switched on in Settings.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Text('Display', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _numberField(_popularity, 'Popularity (0–100)')),
                    const SizedBox(width: 14),
                    Expanded(child: _numberField(_sortOrder, 'Sort order')),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: const Text('Visible in the shop'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isNew ? 'Create package' : 'Save changes'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moneyField(TextEditingController controller, String label,
      {bool required = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, suffixText: 'Ks'),
      validator: required
          ? (value) {
              final parsed = int.tryParse((value ?? '').trim());
              return parsed == null || parsed < 0 ? 'Enter a price' : null;
            }
          : null,
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
    );
  }
}
