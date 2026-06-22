import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entfernt doppelte Roh-Zeilen anhand ihrer `id` (erste gewinnt, Reihenfolge
/// bleibt). Schutz gegen doppelte Anzeige UND doppelte Verrechnung, falls der
/// Supabase-Realtime-Stream (oder der Cache) dieselbe Zeile mehrfach liefert –
/// das ist sicherheitskritisch, weil Salden/Summen sonst doppelt zählen.
List<Map<String, dynamic>> dedupRowsById(List<Map<String, dynamic>> rows) {
  final seen = <Object?>{};
  final out = <Map<String, dynamic>>[];
  for (final r in rows) {
    if (seen.add(r['id'])) out.add(r);
  }
  return out;
}

/// Wird in `main()` per Override mit der echten Instanz versorgt.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPrefsProvider muss in main() überschrieben werden',
  );
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

  // v4: dedupliziert gespeicherte Zeilen (alte, evtl. doppelte Caches verwerfen).
  String _key(String table) => 'cache_v4_$table';

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

  /// Entfernt eine Zeile sofort aus dem Cache (z. B. nach dem Löschen),
  /// damit sie nicht bis zum nächsten Stream-Update sichtbar bleibt.
  void removeFromCache(String table, String id) =>
      removeWhereFromCache(table, (r) => r['id'] == id);

  void removeWhereFromCache(
    String table,
    bool Function(Map<String, dynamic>) test,
  ) {
    final rows = List<Map<String, dynamic>>.from(readRows(table));
    if (rows.isEmpty) return;
    rows.removeWhere(test);
    writeRows(table, rows);
  }
}
