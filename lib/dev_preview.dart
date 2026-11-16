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
import 'features/accounts/account_detail_screen.dart';
import 'features/accounts/account_form_screen.dart';
import 'features/accounts/account_groups_screen.dart';
import 'features/accounts/accounts_screen.dart';
import 'config/app_config.dart';
import 'features/archive/archive_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/export/csv_import_screen.dart';
import 'features/export/export_screen.dart';
import 'features/more/more_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/projects/projects_screen.dart';
import 'features/recurring/recurring_form_screen.dart';
import 'features/reservations/reservation_form_screen.dart';
import 'features/transactions/transaction_form_screen.dart';
import 'features/reservations/reservations_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
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
  StatefulShellBranch branch(
    String path,
    Widget screen, [
    List<RouteBase> sub = const [],
  ]) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => screen, routes: sub)],
  );
  GoRoute page(String path, Widget screen) =>
      GoRoute(path: path, builder: (_, _) => screen);
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainScaffold(shell: shell),
        branches: [
          branch('/', const AccountsScreen(), [
            page('account/groups', const AccountGroupsScreen()),
            page('account/new', const AccountFormScreen()),
            GoRoute(
              path: 'account/:id',
              builder: (_, state) =>
                  AccountDetailScreen(accountId: state.pathParameters['id']!),
            ),
          ]),
          branch('/transactions', const AllTransactionsScreen(), [
            page('new', const TransactionFormScreen()),
            GoRoute(
              path: ':txId',
              builder: (_, state) => TransactionFormScreen(
                transactionId: state.pathParameters['txId'],
              ),
            ),
          ]),
          branch('/statistics', const StatisticsScreen()),
          // Unterseiten, die mit den Beispieldaten auskommen.
          branch('/more', const MoreScreen(), [
            page('search', const SearchScreen()),
            page('projects', const ProjectsScreen()),
            page('reservations', const ReservationsScreen()),
            page('reservations/new', const ReservationFormScreen()),
            page('recurring/new', const RecurringFormScreen()),
            page('settings', const SettingsScreen()),
            page('archive', const ArchiveScreen()),
            page('profile', const ProfileScreen()),
            page('export', const ExportScreen()),
            page('import', const CsvImportScreen()),
          ]),
        ],
      ),
      // Einstieg: liegt in der App außerhalb der Shell (Onboarding sogar vor
      // Riverpod); hier nur zum Ansehen, Absenden meldet einen Beispielfehler.
      page('/login', const LoginScreen()),
      page('/reset-password', const ResetPasswordScreen()),
      page(
        '/onboarding',
        Consumer(
          builder: (context, ref, _) => OnboardingScreen(
            config: ref.watch(appConfigProvider),
            onSubmit: (_, _) async => 'Vorschau: keine Verbindung',
          ),
        ),
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
                    // Lang drücken: Beispiel-Sheet (Glas) über dem Inhalt.
                    onLongPress: () => showGlassSheet<void>(
                      context:
                          _router.routerDelegate.navigatorKey.currentContext!,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ListTile(
                              title: Text('Beispiel-Sheet'),
                              dense: true,
                            ),
                            for (final (icon, label) in const [
                              (Icons.photo_camera_outlined, 'Foto aufnehmen'),
                              (Icons.photo_library_outlined, 'Aus Galerie'),
                              (Icons.attach_file, 'Datei wählen'),
                            ])
                              ListTile(
                                leading: Icon(icon),
                                title: Text(label),
                                onTap: () => Navigator.pop(ctx),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    onTap: () => setState(
                      () => _palette =
                          _palettes[(_palettes.indexOf(_palette) + 1) %
                              _palettes.length],
                    ),
                    child: const SizedBox.square(
                      dimension: 40,
                      child: Icon(Icons.palette_outlined, size: 20),
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
