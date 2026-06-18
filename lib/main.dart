import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/local/app_cache.dart';
import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Deutsche Datums-/Zahlenformate verfügbar machen (sonst werfen
  // DateFormat(..., 'de')-Aufrufe eine LocaleDataException).
  await initializeDateFormatting('de', null);
  final prefs = await SharedPreferences.getInstance();
  runApp(_Bootstrap(prefs: prefs));
}

/// Startsequenz: prüft die (Laufzeit-)Konfiguration, initialisiert Supabase und
/// zeigt sonst das Onboarding. So braucht eine fremde Instanz keine
/// Build-Konfiguration – die Zugangsdaten kommen beim ersten Start.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap({required this.prefs});

  final SharedPreferences prefs;

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final AppConfig _config = AppConfig(widget.prefs);
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

    if (_initializing) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
