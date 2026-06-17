import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_config.dart';

/// Laufzeit-Konfiguration der Supabase-Verbindung.
///
/// Auflösungsreihenfolge:
///   1. Compile-Zeit-Werte aus `--dart-define-from-file=env.json`
///      (für die eigene/Entwickler-Instanz – haben Vorrang).
///   2. Lokal gespeicherte Werte (vom Onboarding eingegeben).
///   3. Nichts → Onboarding-Screen beim ersten Start.
///
/// So kann eine fremde Person das Repo forken, ein eigenes Supabase-Projekt
/// anlegen und die App beim ersten Start ihre Zugangsdaten eingeben lassen –
/// ganz ohne den Code zu bearbeiten oder neu zu bauen.
class AppConfig {
  AppConfig(this._prefs);

  final SharedPreferences _prefs;

  static const _kUrl = 'cfg_supabase_url';
  static const _kKey = 'cfg_supabase_key';

  /// true, wenn die Werte fest per env.json/dart-define gesetzt sind. Dann
  /// kann/braucht der Nutzer sie zur Laufzeit nicht ändern.
  bool get isLockedByEnv =>
      SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty;

  String get url => SupabaseConfig.url.isNotEmpty
      ? SupabaseConfig.url
      : (_prefs.getString(_kUrl) ?? '');

  String get anonKey => SupabaseConfig.anonKey.isNotEmpty
      ? SupabaseConfig.anonKey
      : (_prefs.getString(_kKey) ?? '');

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  Future<void> save({required String url, required String anonKey}) async {
    await _prefs.setString(_kUrl, url.trim());
    await _prefs.setString(_kKey, anonKey.trim());
  }

  Future<void> clear() async {
    await _prefs.remove(_kUrl);
    await _prefs.remove(_kKey);
  }
}

/// Wird in `main()` mit der echten Instanz überschrieben.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider muss in main() gesetzt werden');
});
