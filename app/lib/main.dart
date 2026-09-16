import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/token_store.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Both need disk access, so they are resolved once here and injected into the
  // provider graph rather than being awaited inside widgets.
  final prefs = await SharedPreferences.getInstance();
  final tokens = await TokenStore.create();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
      child: const DiaShopApp(),
    ),
  );
}
