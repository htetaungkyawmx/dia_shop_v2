import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../widgets/common.dart';

/// Shared chrome for the sign-in and sign-up screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: MaxWidthBody(
          maxWidth: 460,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 24),
                Text(title, style: theme.textTheme.displaySmall),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                ...body,
                const SizedBox(height: 20),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthValidators {
  const AuthValidators._();

  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? email(String? value, String required, String invalid) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return required;
    if (!_emailPattern.hasMatch(text)) return invalid;
    return null;
  }

  static String? password(String? value, String required, String rule) {
    final text = value ?? '';
    if (text.isEmpty) return required;
    if (text.length < 8) return rule;
    // Matches the server rule so the form fails before the request does.
    if (!RegExp(r'[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) return rule;
    return null;
  }

  static String? notEmpty(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;
}
