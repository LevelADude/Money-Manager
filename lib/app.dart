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
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(settings.palette),
      // Nur „System" hat ein eigenes Dunkel-Gegenstück; feste Paletten gelten
      // unabhängig von der Geräteeinstellung.
      darkTheme: settings.palette == AppPalette.system
          ? AppTheme.systemDark
          : null,
      themeMode: settings.palette == AppPalette.system
          ? ThemeMode.system
          : ThemeMode.light,
      locale: Locale(settings.localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
    );
  }
}
