import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Shown while the stored session is being checked on a cold start, so the
/// shell never renders (and never fetches) before we know who is signed in.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AdminTheme.brand,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.shield_moon_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ],
        ),
      ),
    );
  }
}
