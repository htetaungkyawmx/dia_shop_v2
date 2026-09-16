import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin_catalog.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/image_url_field.dart';

/// Create or edit a product, including the input fields buyers must fill in
/// (Player ID, Server, account email…).
class ProductEditor extends ConsumerStatefulWidget {
  const ProductEditor({super.key, this.product, required this.categories});

  final AdminProduct? product;
  final List<AdminCategory> categories;

  static Future<bool?> show(
    BuildContext context, {
    AdminProduct? product,
    required List<AdminCategory> categories,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: ProductEditor(product: product, categories: categories),
        ),
      ),
    );
  }

  @override
  ConsumerState<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends ConsumerState<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _slug;
  late final TextEditingController _name;
  late final TextEditingController _nameMy;
  late final TextEditingController _description;
  late final TextEditingController _descriptionMy;
  late final TextEditingController _imageUrl;
  late final TextEditingController _bannerUrl;
  late final TextEditingController _instructions;
  late final TextEditingController _instructionsMy;
  late final TextEditingController _sortOrder;

  late int _categoryId;
  late String _fulfillment;
  late bool _featured;
  late bool _active;
  late List<AdminProductField> _fields;
  bool _busy = false;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _slug = TextEditingController(text: p?.slug ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _nameMy = TextEditingController(text: p?.nameMy ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _descriptionMy = TextEditingController(text: p?.descriptionMy ?? '');
    _imageUrl = TextEditingController(text: p?.imageUrl ?? '');
    _bannerUrl = TextEditingController(text: p?.bannerUrl ?? '');
    _instructions = TextEditingController(text: p?.instructions ?? '');
    _instructionsMy = TextEditingController(text: p?.instructionsMy ?? '');
    _sortOrder = TextEditingController(text: '${p?.sortOrder ?? 0}');
    _categoryId = p?.categoryId ?? (widget.categories.isEmpty ? 0 : widget.categories.first.id);
    _fulfillment = p?.fulfillmentType ?? 'MANUAL';
    _featured = p?.featured ?? false;
    _active = p?.active ?? true;
    _fields = List.of(p?.fields ?? const []);
  }

  @override
  void dispose() {
    for (final c in [
      _slug, _name, _nameMy, _description, _descriptionMy,
      _imageUrl, _bannerUrl, _instructions, _instructionsMy, _sortOrder,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _emptyToNull(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final body = <String, dynamic>{
      'categoryId': _categoryId,
      'slug': _slug.text.trim(),
      'name': _name.text.trim(),
      'nameMy': _emptyToNull(_nameMy),
      'description': _emptyToNull(_description),
      'descriptionMy': _emptyToNull(_descriptionMy),
      'imageUrl': _emptyToNull(_imageUrl),
      'bannerUrl': _emptyToNull(_bannerUrl),
      'instructions': _emptyToNull(_instructions),
      'instructionsMy': _emptyToNull(_instructionsMy),
      'fulfillmentType': _fulfillment,
      'featured': _featured,
      'sortOrder': int.tryParse(_sortOrder.text.trim()) ?? 0,
      'active': _active,
      'fields': _fields.map((f) => f.toRequestJson()).toList(),
    };

    try {
      await ref.read(apiProvider).saveProduct(body, id: widget.product?.id);
      if (mounted) {
        AdminSnack.success(context, _isNew ? 'Product created' : 'Product updated');
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editField({AdminProductField? existing, int? index}) async {
    final result = await showDialog<AdminProductField>(
      context: context,
      builder: (context) => _FieldDialog(field: existing),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _fields = [..._fields, result];
      } else {
        _fields = [..._fields]..[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(_isNew ? 'New product' : 'Edit product',
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
                      flex: 2,
                      child: TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _slug,
                        decoration: const InputDecoration(
                          labelText: 'Slug',
                          helperText: 'lowercase-with-dashes',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9-]')),
                        ],
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
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
                        decoration: const InputDecoration(labelText: 'Burmese name (optional)'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _categoryId == 0 ? null : _categoryId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [
                          for (final c in widget.categories)
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (value) => setState(() => _categoryId = value ?? _categoryId),
                        validator: (value) => value == null ? 'Pick a category' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _fulfillment,
                  decoration: const InputDecoration(labelText: 'Fulfilment'),
                  items: const [
                    DropdownMenuItem(
                      value: 'MANUAL',
                      child: Text('Manual — your team delivers after the order'),
                    ),
                    DropdownMenuItem(
                      value: 'CODE_DELIVERY',
                      child: Text('Code delivery — buyer gets a key instantly'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _fulfillment = value ?? 'MANUAL'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionMy,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Burmese description'),
                ),
                const SizedBox(height: 14),
                ImageUrlField(controller: _imageUrl, label: 'Product image (square works best)'),
                const SizedBox(height: 14),
                ImageUrlField(controller: _bannerUrl, label: 'Banner image (wide)', folder: 'banners'),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _instructions,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'How it works (shown on the product page)',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _instructionsMy,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'How it works · Burmese'),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text('Customer input fields', style: theme.textTheme.titleSmall),
                    ),
                    TextButton.icon(
                      onPressed: () => _editField(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add field'),
                    ),
                  ],
                ),
                Text(
                  'What the buyer must give you so the order can be fulfilled.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                if (_fields.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No fields — the buyer just pays and you deliver.'),
                  )
                else
                  for (var i = 0; i < _fields.length; i++)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(_fields[i].label),
                        subtitle: Text(
                          '${_fields[i].key} · ${_fields[i].inputType.toLowerCase()}'
                          '${_fields[i].required ? ' · required' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _editField(existing: _fields[i], index: i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              onPressed: () =>
                                  setState(() => _fields = [..._fields]..removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sortOrder,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Sort order'),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _featured,
                            onChanged: (value) => setState(() => _featured = value),
                            title: const Text('Featured on home'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            value: _active,
                            onChanged: (value) => setState(() => _active = value),
                            title: const Text('Visible in the shop'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
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
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isNew ? 'Create product' : 'Save changes'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldDialog extends StatefulWidget {
  const _FieldDialog({this.field});

  final AdminProductField? field;

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _key;
  late final TextEditingController _label;
  late final TextEditingController _labelMy;
  late final TextEditingController _placeholder;
  late final TextEditingController _regex;
  late final TextEditingController _options;
  late String _type;
  late bool _required;

  @override
  void initState() {
    super.initState();
    final f = widget.field;
    _key = TextEditingController(text: f?.key ?? '');
    _label = TextEditingController(text: f?.label ?? '');
    _labelMy = TextEditingController(text: f?.labelMy ?? '');
    _placeholder = TextEditingController(text: f?.placeholder ?? '');
    _regex = TextEditingController(text: f?.validationRegex ?? '');
    _options = TextEditingController(text: (f?.options ?? const []).join(', '));
    _type = f?.inputType ?? 'TEXT';
    _required = f?.required ?? true;
  }

  @override
  void dispose() {
    for (final c in [_key, _label, _labelMy, _placeholder, _regex, _options]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.field == null ? 'Add field' : 'Edit field'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: 'Label', hintText: 'Player ID'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _key,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    helperText: 'lowercase_with_underscores, used in the order record',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]'))],
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _labelMy,
                  decoration: const InputDecoration(labelText: 'Burmese label (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _placeholder,
                  decoration: const InputDecoration(labelText: 'Placeholder (optional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Input type'),
                  items: const [
                    DropdownMenuItem(value: 'TEXT', child: Text('Text')),
                    DropdownMenuItem(value: 'NUMBER', child: Text('Number')),
                    DropdownMenuItem(value: 'EMAIL', child: Text('Email')),
                    DropdownMenuItem(value: 'SELECT', child: Text('Choice list')),
                  ],
                  onChanged: (value) => setState(() => _type = value ?? 'TEXT'),
                ),
                if (_type == 'SELECT') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _options,
                    decoration: const InputDecoration(
                      labelText: 'Choices',
                      helperText: 'Separate with commas',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _regex,
                  decoration: const InputDecoration(
                    labelText: 'Validation pattern (optional)',
                    helperText: r'e.g. ^[0-9]{5,15}$',
                  ),
                ),
                SwitchListTile(
                  value: _required,
                  onChanged: (value) => setState(() => _required = value),
                  title: const Text('Required'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              AdminProductField(
                id: widget.field?.id,
                key: _key.text.trim(),
                label: _label.text.trim(),
                labelMy: _labelMy.text.trim().isEmpty ? null : _labelMy.text.trim(),
                placeholder: _placeholder.text.trim().isEmpty ? null : _placeholder.text.trim(),
                inputType: _type,
                options: _type == 'SELECT'
                    ? _options.text
                        .split(',')
                        .map((o) => o.trim())
                        .where((o) => o.isNotEmpty)
                        .toList()
                    : const [],
                validationRegex: _regex.text.trim().isEmpty ? null : _regex.text.trim(),
                required: _required,
                sortOrder: widget.field?.sortOrder ?? 0,
              ),
            );
          },
          child: const Text('Save field'),
        ),
      ],
    );
  }
}
