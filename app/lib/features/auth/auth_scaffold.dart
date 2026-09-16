import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../widgets/layout.dart';

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
    final form = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!Breakpoints.isWide(context)) ...[
              const Align(
                  alignment: Alignment.centerLeft, child: AppLogo(size: 72)),
              const SizedBox(height: 20),
            ],
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
    );

    if (!Breakpoints.isWide(context)) {
      return Scaffold(
        appBar: AppBar(),
        body: SafeArea(top: false, child: Center(child: form)),
      );
    }

    // Wide windows: brand panel on the left, the form on the right.
    return Scaffold(
      body: Row(
        children: [
          Expanded(
              child: _BrandPanel(
                  onClose: () =>
                      context.canPop() ? context.pop() : context.go('/'))),
          Expanded(child: Center(child: form)),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2170), Color(0xFF0E1016)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(strings.home),
          ),
          const Spacer(),
          const AppLogo(size: 180),
          const SizedBox(height: 28),
          Text(
            strings.appName,
            style: theme.textTheme.displaySmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              strings.tagline,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: Colors.white70, height: 1.5),
            ),
          ),
          const Spacer(flex: 2),
        ],
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
    if (!RegExp(r'[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
      return rule;
    }
    return null;
  }

  static String? notEmpty(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;
}
