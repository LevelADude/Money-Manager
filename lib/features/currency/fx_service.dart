import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live-Wechselkurse relativ zu einer Basiswährung.
///
/// [ratesToBase] speichert – passend zur App-Konvention – **Einheiten der
/// Basiswährung je 1 Einheit der Fremdwährung** (rate_to_base). Die API liefert
/// den Kehrwert (Fremd je 1 Basis), daher wird beim Laden invertiert.
class FxRates {
  const FxRates({
    required this.base,
    required this.ratesToBase,
    required this.fetchedAtMs,
  });

  final String base;
  final Map<String, double> ratesToBase;
  final int fetchedAtMs;

  Map<String, dynamic> toJson() => {
    'base': base,
    'rates': ratesToBase,
    'ts': fetchedAtMs,
  };

  factory FxRates.fromJson(Map<String, dynamic> j) => FxRates(
    base: j['base'] as String,
    ratesToBase: {
      for (final e in (j['rates'] as Map).entries)
        e.key as String: (e.value as num).toDouble(),
    },
    fetchedAtMs: (j['ts'] as num).toInt(),
  );
}

/// Holt Live-Kurse von open.er-api.com (kostenlos, ohne API-Key, 160+
/// Währungen, tägliche Aktualisierung).
class FxService {
  const FxService();

  Future<FxRates?> fetch(String base) async {
    final code = base.trim().toUpperCase();
    final uri = Uri.parse('https://open.er-api.com/v6/latest/$code');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['result'] != 'success') return null;
      final rates = body['rates'] as Map<String, dynamic>?;
      if (rates == null) return null;
      final toBase = <String, double>{};
      for (final e in rates.entries) {
        if (e.key == code) continue;
        final v = (e.value as num?)?.toDouble();
        if (v != null && v > 0) toBase[e.key] = 1 / v; // Basis je 1 Fremd
      }
      if (toBase.isEmpty) return null;
      return FxRates(
        base: code,
        ratesToBase: toBase,
        fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null; // Offline / Timeout / ungültige Antwort
    }
  }
}
