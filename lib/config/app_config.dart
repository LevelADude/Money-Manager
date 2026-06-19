import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_config.dart';

/// Laufzeit-Konfiguration der Supabase-Verbindung.
///
/// Auflösungsreihenfolge (höchste zuerst):
///   1. Lokaler, manuell gesetzter Override (pro Gerät, „Verbindung ändern").
///   2. Fest eingebauter Standard ([SupabaseConfig], per Repo/dart-define).
///   3. Nichts gesetzt → Onboarding-Screen beim ersten Start.
///
/// Dadurch ist die Datenbank-URL pro Repo FEST vorgegeben (jedes Gerät verbindet
/// sich automatisch, ohne Nachfrage) – kann aber bei Bedarf pro Gerät manuell
/// geändert (Override) und jederzeit auf den Standard zurückgesetzt werden.
class AppConfig {
  AppConfig(this._prefs);

  final SharedPreferences _prefs;

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

  String get url => _overrideUrl ?? SupabaseConfig.url;
  String get anonKey => _overrideKey ?? SupabaseConfig.anonKey;

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Gibt es eine fest eingebaute Standard-Verbindung (Repo/dart-define)?
  bool get hasBakedDefault =>
      SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty;

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
