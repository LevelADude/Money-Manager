/// Supabase-Zugangsdaten (fest pro Repo eingebaut).
///
/// Diese Werte sind die feste Standard-Verbindung dieser Instanz. URL und
/// "publishable/anon key" sind absichtlich öffentliche Client-Werte (sie
/// stecken ohnehin in jedem ausgelieferten Web-Build); geschützt wird der
/// Zugriff durch RLS + die E-Mail-Whitelist beim Registrieren. Dadurch braucht
/// KEIN Gerät beim ersten Start nach der URL gefragt zu werden.
///
/// Überschreibbar:
///   * pro Build via `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
///     (z. B. für einen Fork mit eigener Datenbank), und
///   * pro Gerät zur Laufzeit über „Datenbank-Verbindung ändern" (gespeichert
///     in den lokalen Einstellungen, siehe [AppConfig]).
///
/// Ein Fork mit eigener Datenbank ersetzt einfach die beiden Default-Werte
/// unten (oder gibt sie per dart-define an).
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://uaaqehspnlncjzrajfue.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_jLK-YtaH2uZAWLDYQJyoDw_0oVLODO2',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
