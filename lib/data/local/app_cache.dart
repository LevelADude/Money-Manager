import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wird in `main()` per Override mit der echten Instanz versorgt.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider muss in main() überschrieben werden');
});

final appCacheProvider = Provider<AppCache>((ref) {
  return AppCache(ref.watch(sharedPrefsProvider));
});

/// Lokaler Offline-Cache der DB-Zeilen (Local-First-Lite).
///
/// Speichert die zuletzt empfangenen Rohdaten je Tabelle als JSON in
/// `shared_preferences` (funktioniert auf Windows, Android und Web). Die App
/// kann dadurch **sofort** und **offline** die letzten bekannten Daten zeigen;
/// sobald online, aktualisiert der Supabase-Realtime-Stream den Cache.
class AppCache {
  AppCache(this._prefs);

  final SharedPreferences _prefs;

  String _key(String table) => 'cache_v2_$table';

  /// Liefert die zuletzt gecachten Roh-Zeilen einer Tabelle (oder leer).
  List<Map<String, dynamic>> readRows(String table) {
    final raw = _prefs.getString(_key(table));
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  /// Persistiert die Roh-Zeilen einer Tabelle (fire-and-forget).
  void writeRows(String table, List<Map<String, dynamic>> rows) {
    _prefs.setString(_key(table), jsonEncode(rows));
  }
}
