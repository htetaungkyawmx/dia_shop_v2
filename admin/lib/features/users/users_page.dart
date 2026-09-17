import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/admin_catalog.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  UserFilter _filter = const UserFilter();

  void _refresh() => ref.invalidate(usersProvider);

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider(_filter));
    final me = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          SearchField(
            hint: 'Email, name or phone',
            onChanged: (value) => setState(
              () => _filter = UserFilter(
                  query: value, status: _filter.status, role: _filter.role),
            ),
          ),
          const SizedBox(width: 12),
          if (me?.role == 'SUPER_ADMIN')
            if (MediaQuery.sizeOf(context).width < 760)
              IconButton.filled(
                tooltip: 'Add staff',
                onPressed: () => _createStaff(context),
                icon: const Icon(Icons.person_add_alt_rounded, size: 20),
              )
            else
              FilledButton.icon(
                onPressed: () => _createStaff(context),
                icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: const Text('Add staff'),
              ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Wrap(
              spacing: 8,
              children: [
                _chip(null, null, 'All'),
                _chip('ACTIVE', null, 'Active'),
                _chip('SUSPENDED', null, 'Suspended'),
                _chip(null, 'ADMIN', 'Admins'),
              ],
            ),
          ),
          Expanded(
            child: AsyncSection(
              value: users,
              onRetry: _refresh,
              loadingHeight: 420,
              builder: (page) {
                if (page.items.isEmpty) {
                  return const AdminEmpty(
                      icon: Icons.people_rounded, title: 'No customers found');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _UserRow(
                    user: page.items[index],
                    isSelf: page.items[index].email == me?.email,
                    canChangeRole: me?.role == 'SUPER_ADMIN',
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

  Widget _chip(String? status, String? role, String label) {
    final selected = _filter.status == status && _filter.role == role;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(
        () => _filter =
            UserFilter(query: _filter.query, status: status, role: role),
      ),
    );
  }

  Future<void> _createStaff(BuildContext context) async {
    final email = TextEditingController();
    final name = TextEditingController();
    final password = TextEditingController();
    String role = 'ADMIN';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add staff account'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                    helperText: 'At least 8 characters',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    DropdownMenuItem(
                        value: 'SUPER_ADMIN', child: Text('Super admin')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? 'ADMIN'),
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    final values = (
      email: email.text.trim(),
      name: name.text.trim(),
      password: password.text,
      role: role,
    );
    email.dispose();
    name.dispose();
    password.dispose();

    if (confirmed != true ||
        values.email.isEmpty ||
        values.password.length < 8) {
      return;
    }

    try {
      await ref.read(apiProvider).createStaff(
            email: values.email,
            password: values.password,
            displayName: values.name,
            role: values.role,
          );
      _refresh();
      if (context.mounted) AdminSnack.success(context, 'Staff account created');
    } catch (error) {
      if (context.mounted) AdminSnack.error(context, error);
    }
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({
    required this.user,
    required this.isSelf,
    required this.canChangeRole,
    required this.onChanged,
  });

  final AdminUser user;
  final bool isSelf;
  final bool canChangeRole;
  final VoidCallback onChanged;

  Future<void> _adjustBalance(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final reason = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust balance'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${user.displayName} · ${user.email}'),
              Text('Current balance: ${Format.money(user.balance)}'),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  helperText: 'Negative removes money, e.g. -5000',
                  suffixText: 'Ks',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  helperText: 'Shown to the customer in their wallet history',
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
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    final value = int.tryParse(amount.text.trim());
    final note = reason.text.trim();
    amount.dispose();
    reason.dispose();

    if (confirmed != true || value == null || value == 0 || note.isEmpty) {
      return;
    }

    try {
      await ref
          .read(apiProvider)
          .adjustBalance(user.id, amount: value, reason: note);
      onChanged();
      if (context.mounted) {
        AdminSnack.success(
            context, '${Format.signedMoney(value)} applied to ${user.email}');
      }
    } catch (error) {
      if (context.mounted) AdminSnack.error(context, error);
    }
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: Text(
          'Give ${user.email} a temporary password? They will be signed out of every device '
          'and must use the new password to sign in.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final temporary = await ref.read(apiProvider).resetPassword(user.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Temporary password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send this to ${user.displayName}. It is shown only once.'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      temporary,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(letterSpacing: 1.5),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: temporary));
                      if (context.mounted) {
                        AdminSnack.success(context, 'Copied');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'))
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) AdminSnack.error(context, error);
    }
  }

  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(apiProvider).updateUser(user.id, {'status': status});
      onChanged();
      if (context.mounted) {
        AdminSnack.success(context,
            status == 'ACTIVE' ? 'Account restored' : 'Account suspended');
      }
    } catch (error) {
      if (context.mounted) AdminSnack.error(context, error);
    }
  }

  Future<void> _setRole(
      BuildContext context, WidgetRef ref, String role) async {
    try {
      await ref.read(apiProvider).updateUser(user.id, {'role': role});
      onChanged();
      if (context.mounted) {
        AdminSnack.success(context, 'Role updated to ${prettyStatus(role)}');
      }
    } catch (error) {
      if (context.mounted) AdminSnack.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, c) {
          // The full table only fits a wide screen. On a phone the secondary
          // columns are dropped and the balance moves under the e-mail, rather
          // than every column being squeezed until text wraps one letter a line.
          final wide = c.maxWidth >= 820;
          final medium = c.maxWidth >= 620;
          return Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AdminTheme.brand.withValues(alpha: 0.15),
                child: Text(
                  user.displayName.isEmpty
                      ? '?'
                      : user.displayName[0].toUpperCase(),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: AdminTheme.brand),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(user.displayName,
                            style: theme.textTheme.titleSmall),
                        if (user.isAdmin)
                          StatusBadge(
                              status: 'REFUNDED',
                              label: prettyStatus(user.role)),
                        if (user.isSuspended)
                          const StatusBadge(status: 'SUSPENDED'),
                      ],
                    ),
                    Text(
                      user.email,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (!medium)
                      Text(
                        '${Format.money(user.balance)} · ${user.orderCount} order(s)',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (medium)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Format.money(user.balance),
                          style: theme.textTheme.titleSmall),
                      Text(
                        'balance',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              if (wide)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Format.money(user.totalSpent),
                          style: theme.textTheme.bodyMedium),
                      Text(
                        '${user.orderCount} order(s)',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              if (wide)
                SizedBox(
                  width: 96,
                  child: Text(
                    user.lastLoginAt == null
                        ? 'never'
                        : Format.relative(user.lastLoginAt!),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'balance':
                      await _adjustBalance(context, ref);
                    case 'suspend':
                      await _setStatus(context, ref, 'SUSPENDED');
                    case 'activate':
                      await _setStatus(context, ref, 'ACTIVE');
                    case 'make_admin':
                      await _setRole(context, ref, 'ADMIN');
                    case 'make_user':
                      await _setRole(context, ref, 'USER');
                    case 'reset_password':
                      await _resetPassword(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'balance',
                    child: Row(children: [
                      Icon(Icons.tune_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Adjust balance'),
                    ]),
                  ),
                  if (!isSelf) ...[
                    const PopupMenuItem(
                      value: 'reset_password',
                      child: Row(children: [
                        Icon(Icons.key_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Reset password'),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    if (user.isSuspended)
                      const PopupMenuItem(
                        value: 'activate',
                        child: Row(children: [
                          Icon(Icons.lock_open_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Restore account'),
                        ]),
                      )
                    else
                      const PopupMenuItem(
                        value: 'suspend',
                        child: Row(children: [
                          Icon(Icons.block_rounded,
                              size: 18, color: AdminTheme.danger),
                          SizedBox(width: 10),
                          Text('Suspend account'),
                        ]),
                      ),
                    if (canChangeRole)
                      user.isAdmin
                          ? const PopupMenuItem(
                              value: 'make_user',
                              child: Row(children: [
                                Icon(Icons.person_outline_rounded, size: 18),
                                SizedBox(width: 10),
                                Text('Remove admin access'),
                              ]),
                            )
                          : const PopupMenuItem(
                              value: 'make_admin',
                              child: Row(children: [
                                Icon(Icons.admin_panel_settings_outlined,
                                    size: 18),
                                SizedBox(width: 10),
                                Text('Make admin'),
                              ]),
                            ),
                  ],
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}
