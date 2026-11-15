// Design-Vorschau ohne Login und ohne Supabase.
//
// Zeigt die echte Navigation und die vier echten Hauptscreens (Konten,
// Buchungen, Statistik, Mehr) mit Beispieldaten, um Paletten und Layout im
// Browser zu prüfen:
//   flutter run -d web-server --web-port 5175 -t lib/dev_preview.dart
// Palette über den Knopf am linken Rand oder per URL: `?p=sage|emerald|dark`.
// Wird von der App nicht importiert und landet daher nicht im Release-Build.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/main_scaffold.dart';
import 'core/theme.dart';
import 'dev_preview_data.dart';
import 'features/accounts/accounts_screen.dart';
import 'features/more/more_screen.dart';
import 'features/settings/settings_providers.dart';
import 'features/statistics/statistics_screen.dart';
import 'features/transactions/all_transactions_screen.dart';
import 'features/transactions/person_filter.dart';
import 'l10n/app_localizations.dart';
import 'shared/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de', null);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: previewOverrides(prefs),
      child: const PreviewApp(),
    ),
  );
}

/// Router der Vorschau: die echte Shell mit den vier Hauptscreens. Alle
/// anderen Ziele zeigen nur ihren Pfad, damit Antippen nichts kaputt macht.
GoRouter buildPreviewRouter({String initialLocation = '/'}) {
  StatefulShellBranch branch(String path, Widget screen) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => screen)],
  );
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainScaffold(shell: shell),
        branches: [
          branch('/', const AccountsScreen()),
          branch('/transactions', const AllTransactionsScreen()),
          branch('/statistics', const StatisticsScreen()),
          branch('/more', const MoreScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Vorschau'),
      ),
      body: Center(child: Text('Nicht Teil der Vorschau: ${state.uri}')),
    ),
  );
}

class PreviewApp extends ConsumerStatefulWidget {
  const PreviewApp({super.key, this.initialLocation = '/', this.palette});

  final String initialLocation;

  /// Feste Palette (Tests); sonst aus `?p=` bzw. per Knopf umschaltbar.
  final AppPalette? palette;

  @override
  ConsumerState<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends ConsumerState<PreviewApp> {
  late final GoRouter _router = buildPreviewRouter(
    initialLocation: widget.initialLocation,
  );
  static const _palettes = [
    AppPalette.sage,
    AppPalette.emerald,
    AppPalette.dark,
  ];
  late AppPalette _palette =
      widget.palette ??
      _palettes.firstWhere(
        (p) => p.name == Uri.base.queryParameters['p'],
        orElse: () => AppPalette.sage,
      );

  @override
  void initState() {
    super.initState();
    // Gesamtansicht („Alle Personen"), damit auch „Vermögen je Person" und
    // fremde Konten zu sehen sind; `?person=me` zeigt nur die eigenen.
    if (Uri.base.queryParameters['person'] != 'me') {
      Future.microtask(() => ref.read(personFilterProvider.notifier).set(null));
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(settingsProvider.select((s) => s.localeCode));
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(_palette),
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router,
      builder: (context, child) => Stack(
        children: [
          ?child,
          if (widget.palette == null)
            Align(
              alignment: const Alignment(-1, .5),
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Glass(
                  borderRadius: BorderRadius.circular(20),
                  child: PressScale(
                    shape: const CircleBorder(),
                    onTap: () => setState(
                      () => _palette =
                          _palettes[(_palettes.indexOf(_palette) + 1) %
                              _palettes.length],
                    ),
                    child: const Tooltip(
                      message: 'Palette wechseln',
                      child: SizedBox.square(
                        dimension: 40,
                        child: Icon(Icons.palette_outlined, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
