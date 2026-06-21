import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'features/settings/lock_gate.dart';
import 'features/settings/settings_providers.dart';
import 'l10n/app_localizations.dart';

class MoneyManagerApp extends ConsumerWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    final seed = Color(settings.seedColor);
    return MaterialApp.router(
      title: 'Money Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed),
      darkTheme: AppTheme.dark(seed),
      themeMode: settings.themeMode,
      locale: Locale(settings.localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
    );
  }
}
