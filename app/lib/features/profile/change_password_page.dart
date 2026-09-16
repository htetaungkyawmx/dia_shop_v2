import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../auth/auth_scaffold.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final strings = Strings.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            current: _current.text,
            next: _next.text,
          );
      if (!mounted) return;
      AppSnack.success(context, strings.passwordUpdated);
      // The server revokes every session on a password change, so this device
      // has to sign in again with the new password.
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) AppSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.changePassword)),
      body: MaxWidthBody(
        maxWidth: 520,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.currentPassword),
                validator: (value) => AuthValidators.notEmpty(value, strings.passwordRequired),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _next,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.newPassword,
                  helperText: strings.passwordRule,
                  helperMaxLines: 2,
                ),
                validator: (value) =>
                    AuthValidators.password(value, strings.passwordRequired, strings.passwordRule),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(strings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
