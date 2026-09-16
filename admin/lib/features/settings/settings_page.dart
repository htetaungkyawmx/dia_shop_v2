import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/wallet.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final methods = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(settingsProvider);
              ref.invalidate(paymentMethodsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AsyncSection(
            value: settings,
            onRetry: () => ref.invalidate(settingsProvider),
            builder: (values) => Column(
              children: [
                _MaintenanceCard(values: values),
                const SizedBox(height: 20),
                PanelCard(
                  title: 'Shop settings',
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final entry in values.entries)
                        if (entry.key != 'app.maintenance')
                          _SettingRow(settingKey: entry.key, value: entry.value),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AsyncSection(
            value: methods,
            onRetry: () => ref.invalidate(paymentMethodsProvider),
            builder: (list) => PanelCard(
              title: 'Payment methods',
              actions: [
                TextButton.icon(
                  onPressed: () => _editMethod(context, ref, null),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add method'),
                ),
              ],
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final method in list)
                    ListTile(
                      leading: const Icon(Icons.account_balance_rounded),
                      title: Text(method.name),
                      subtitle: Text(
                        '${method.accountName} · ${method.accountNumber} · '
                        '${Format.money(method.minAmount)}–${Format.money(method.maxAmount)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editMethod(context, ref, method),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          PanelCard(
            title: 'Send an announcement',
            child: _BroadcastForm(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editMethod(BuildContext context, WidgetRef ref, PaymentMethod? method) async {
    final code = TextEditingController(text: method?.code ?? '');
    final name = TextEditingController(text: method?.name ?? '');
    final accountName = TextEditingController(text: method?.accountName ?? '');
    final accountNumber = TextEditingController(text: method?.accountNumber ?? '');
    final minAmount = TextEditingController(text: '${method?.minAmount ?? 1000}');
    final maxAmount = TextEditingController(text: '${method?.maxAmount ?? 5000000}');
    final instructions = TextEditingController(text: method?.instructions ?? '');
    final instructionsMy = TextEditingController(text: method?.instructionsMy ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(method == null ? 'Add payment method' : 'Edit ${method.name}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Display name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: code,
                        decoration: const InputDecoration(labelText: 'Code'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountName,
                  decoration: const InputDecoration(labelText: 'Account name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountNumber,
                  decoration: const InputDecoration(labelText: 'Account number'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minAmount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Min', suffixText: 'Ks'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxAmount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Max', suffixText: 'Ks'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instructions,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Instructions (English)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instructionsMy,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Instructions (Burmese)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    final body = {
      'code': code.text.trim(),
      'name': name.text.trim(),
      'accountName': accountName.text.trim(),
      'accountNumber': accountNumber.text.trim(),
      'minAmount': int.tryParse(minAmount.text.trim()) ?? 1000,
      'maxAmount': int.tryParse(maxAmount.text.trim()) ?? 5000000,
      'instructions': instructions.text.trim(),
      'instructionsMy': instructionsMy.text.trim(),
      'sortOrder': 0,
      'active': true,
    };
    for (final c in [
      code, name, accountName, accountNumber, minAmount, maxAmount, instructions, instructionsMy,
    ]) {
      c.dispose();
    }

    if (confirmed != true) return;
    try {
      await ref.read(apiProvider).savePaymentMethod(body, id: method?.id);
      ref.invalidate(paymentMethodsProvider);
      if (context.mounted) AdminSnack.success(context, 'Payment method saved');
    } catch (error) {
      if (context.mounted) AdminSnack.error(context, error);
    }
  }
}

class _MaintenanceCard extends ConsumerWidget {
  const _MaintenanceCard({required this.values});

  final Map<String, String> values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final on = values['app.maintenance'] == 'true';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (on ? AdminTheme.warning : AdminTheme.success).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                on ? Icons.build_rounded : Icons.storefront_rounded,
                color: on ? AdminTheme.warning : AdminTheme.success,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(on ? 'Maintenance mode is on' : 'Shop is open',
                      style: theme.textTheme.titleSmall),
                  Text(
                    on
                        ? 'Customers can browse but cannot place orders.'
                        : 'Customers can browse and order normally.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: on,
              onChanged: (value) async {
                try {
                  await ref
                      .read(apiProvider)
                      .updateSetting('app.maintenance', value.toString());
                  ref.invalidate(settingsProvider);
                  if (context.mounted) {
                    AdminSnack.info(
                        context, value ? 'Shop closed for maintenance' : 'Shop reopened');
                  }
                } catch (error) {
                  if (context.mounted) AdminSnack.error(context, error);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends ConsumerWidget {
  const _SettingRow({required this.settingKey, required this.value});

  final String settingKey;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(settingKey, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        value.isEmpty ? '(empty)' : value,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        onPressed: () async {
          final controller = TextEditingController(text: value);
          final saved = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(settingKey),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Save'),
                ),
              ],
            ),
          );
          controller.dispose();
          if (saved == null) return;
          try {
            await ref.read(apiProvider).updateSetting(settingKey, saved);
            ref.invalidate(settingsProvider);
            if (context.mounted) AdminSnack.success(context, 'Setting saved');
          } catch (error) {
            if (context.mounted) AdminSnack.error(context, error);
          }
        },
      ),
    );
  }
}

class _BroadcastForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BroadcastForm> createState() => _BroadcastFormState();
}

class _BroadcastFormState extends ConsumerState<_BroadcastForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      AdminSnack.info(context, 'Add a title and a message first.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send to every customer?'),
        content: Text('"${_title.text.trim()}" will appear in everyone\'s notifications.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).broadcast(title: _title.text.trim(), body: _body.text.trim());
      _title.clear();
      _body.clear();
      if (mounted) AdminSnack.success(context, 'Announcement sent');
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _body,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.campaign_rounded, size: 18),
          label: const Text('Send to all customers'),
        ),
      ],
    );
  }
}
