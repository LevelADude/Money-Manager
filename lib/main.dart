import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'config/db_connection_file.dart';
import 'data/local/app_cache.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Deutsche Datums-/Zahlenformate verfügbar machen (sonst werfen
  // DateFormat(..., 'de')-Aufrufe eine LocaleDataException).
  await initializeDateFormatting('de', null);
  final prefs = await SharedPreferences.getInstance();
  // Fest ins Repo eingecheckte Verbindung (assets/db_connection/connection.json)
  // laden – bindet dieses Repo an seine Datenbank. Fehlt sie → Onboarding.
  final fileConn = await DbConnectionFile.load();
  runApp(_Bootstrap(prefs: prefs, fileConn: fileConn));
}

/// Startsequenz: prüft die (Laufzeit-)Konfiguration, initialisiert Supabase und
/// zeigt sonst das Onboarding. So braucht eine fremde Instanz keine
/// Build-Konfiguration – die Zugangsdaten kommen beim ersten Start.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap({required this.prefs, this.fileConn});

  final SharedPreferences prefs;

  /// Verbindung aus der Repo-Datei (oder null, wenn nicht vorhanden/gültig).
  final ({String url, String anonKey})? fileConn;

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final AppConfig _config = AppConfig(
    widget.prefs,
    fileUrl: widget.fileConn?.url,
    fileKey: widget.fileConn?.anonKey,
  );
  bool _initializing = true;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_config.isConfigured) {
      _initSupabase();
    } else {
      _initializing = false; // direkt ins Onboarding
    }
  }

  Future<void> _initSupabase() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      await Supabase.initialize(
        url: _config.url,
        // Akzeptiert sowohl den neuen "publishable key" als auch den
        // klassischen "anon"-Key (beide sind clientseitig öffentlich).
        publishableKey: _config.anonKey,
      );
      if (!mounted) return;
      setState(() {
        _ready = true;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _initializing = false;
      });
    }
  }

  /// Vom Onboarding aufgerufen: speichert die Werte und verbindet. Gibt eine
  /// Fehlermeldung zurück (oder null bei Erfolg).
  Future<String?> _onSubmit(String url, String anonKey) async {
    await _config.save(url: url, anonKey: anonKey);
    await _initSupabase();
    return _error;
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(widget.prefs),
          appConfigProvider.overrideWithValue(_config),
        ],
        child: const MoneyManagerApp(),
      );
    }

    // Sprache aus den Einstellungen (Default Deutsch) – auch schon vor der
    // Riverpod-Initialisierung, damit Lade- und Onboarding-Screen lokalisiert
    // sind.
    final locale = Locale(
      widget.prefs.getString('settings_locale') == 'en' ? 'en' : 'de',
    );

    if (_initializing) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: OnboardingScreen(
        config: _config,
        initialError: _error,
        onSubmit: _onSubmit,
      ),
    );
  }
}
