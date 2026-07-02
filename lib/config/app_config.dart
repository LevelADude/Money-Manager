import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_config.dart';

/// Laufzeit-Konfiguration der Supabase-Verbindung.
///
/// Auflösungsreihenfolge (höchste zuerst):
///   1. Lokaler, manuell gesetzter Override (pro Gerät, „Verbindung ändern").
///   2. Fest eingecheckte Repo-Datei `assets/db_connection/connection.json`
///      (bindet das Repo fest an eine Datenbank; siehe [DbConnectionFile]).
///   3. Per dart-define eingebauter Standard ([SupabaseConfig], z. B. env.json
///      lokal oder GitHub-Secrets im Web-Deploy).
///   4. Nichts gesetzt → Onboarding-Screen beim ersten Start.
///
/// Dadurch ist die Datenbank-URL pro Repo FEST vorgegeben (jedes Gerät verbindet
/// sich automatisch, ohne Nachfrage) – kann aber bei Bedarf pro Gerät manuell
/// geändert (Override) und jederzeit auf den Standard zurückgesetzt werden.
class AppConfig {
  AppConfig(this._prefs, {String? fileUrl, String? fileKey})
    : _fileUrl = (fileUrl != null && fileUrl.isNotEmpty) ? fileUrl : null,
      _fileKey = (fileKey != null && fileKey.isNotEmpty) ? fileKey : null;

  final SharedPreferences _prefs;

  /// Aus der Repo-Datei geladene Verbindung (zur Startzeit gesetzt), oder null.
  final String? _fileUrl;
  final String? _fileKey;

  static const _kUrl = 'cfg_supabase_url';
  static const _kKey = 'cfg_supabase_key';

  String? get _overrideUrl {
    final v = _prefs.getString(_kUrl);
    return (v != null && v.isNotEmpty) ? v : null;
  }

  String? get _overrideKey {
    final v = _prefs.getString(_kKey);
    return (v != null && v.isNotEmpty) ? v : null;
  }

  /// Eingebauter Standard: Repo-Datei zuerst, sonst dart-define.
  String get _bakedUrl => _fileUrl ?? SupabaseConfig.url;
  String get _bakedKey => _fileKey ?? SupabaseConfig.anonKey;

  String get url => _overrideUrl ?? _bakedUrl;
  String get anonKey => _overrideKey ?? _bakedKey;

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Gibt es eine fest eingebaute Standard-Verbindung (Repo-Datei/dart-define)?
  bool get hasBakedDefault => _bakedUrl.isNotEmpty && _bakedKey.isNotEmpty;

  /// Wird gerade ein lokaler Override statt des Standards verwendet?
  bool get isUsingOverride => _overrideUrl != null || _overrideKey != null;

  Future<void> save({required String url, required String anonKey}) async {
    await _prefs.setString(_kUrl, url.trim());
    await _prefs.setString(_kKey, anonKey.trim());
  }

  /// Entfernt den lokalen Override → zurück zur eingebauten Standard-Verbindung
  /// (bzw. Onboarding, falls kein Standard eingebaut ist).
  Future<void> clear() async {
    await _prefs.remove(_kUrl);
    await _prefs.remove(_kKey);
  }
}

/// Wird in `main()` mit der echten Instanz überschrieben.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider muss in main() gesetzt werden');
});

/// Verbindet nach einer Änderung der DB-Verbindung neu, OHNE dass der Nutzer
/// die App manuell neu starten muss (wichtig auf Android: dort beendet
/// "App schliessen" den Prozess meist nicht wirklich, ein simples
/// `Supabase.initialize()` nach dem ersten Aufruf ist ein No-Op). Baut dazu
/// den kompletten Widget-Baum unterhalb des Bootstraps neu auf – siehe
/// [main.dart]'s `_BootstrapState.restart()`.
final appRestartProvider = Provider<Future<void> Function()>((ref) {
  throw UnimplementedError('appRestartProvider muss in main() gesetzt werden');
});
