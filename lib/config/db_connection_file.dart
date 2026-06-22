import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Liest die fest ins Repo eingecheckte Datenbank-Verbindung aus
/// `assets/db_connection/connection.json`.
///
/// Diese Datei bindet das Repo fest an eine Supabase-Datenbank: ist sie
/// vorhanden und gueltig, verbindet sich jedes Geraet automatisch (kein
/// Onboarding). Fehlt die Datei (von einem neuen Nutzer geloescht) oder ist sie
/// leer/ungueltig, faellt die App auf die naechste Quelle zurueck (dart-define
/// bzw. Onboarding).
///
/// URL + anon/publishable-Key sind oeffentliche Client-Werte; der Schutz der
/// Daten erfolgt ueber RLS + E-Mail-Whitelist, nicht ueber Geheimhaltung.
class DbConnectionFile {
  const DbConnectionFile._();

  static const assetPath = 'assets/db_connection/connection.json';

  /// Laedt die Verbindung oder gibt `null` zurueck, wenn die Datei fehlt,
  /// leer oder ungueltig ist (dann greift das normale Onboarding).
  static Future<({String url, String anonKey})?> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      if (raw.trim().isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final url = (map['url'] as String?)?.trim() ?? '';
      // Sowohl "anonKey" als auch "anon_key" akzeptieren.
      final key =
          ((map['anonKey'] ?? map['anon_key']) as String?)?.trim() ?? '';
      if (url.isEmpty || key.isEmpty) return null;
      // Platzhalterwerte aus der README ignorieren.
      if (url.contains('DEIN-PROJEKT') || key.startsWith('DEIN-')) return null;
      return (url: url, anonKey: key);
    } catch (_) {
      // Datei fehlt oder ist ungueltig -> Onboarding.
      return null;
    }
  }
}
