/// Supabase-Zugangsdaten (zur BUILD-Zeit eingebacken, NICHT im Quellcode).
///
/// Bewusst leer als eingecheckter Standard: So startet ein frischer Klon/Fork
/// LEER und zeigt das Onboarding, statt sich still mit einer fremden Datenbank
/// zu verbinden. Jede Instanz bindet ihre eigene Datenbank an.
///
/// Eine konkrete Instanz (auch die des Besitzers) gibt ihre Werte per
/// `--dart-define` an — NICHT durch Eintragen hier:
///   * lokal (Windows/Android): über `env.json` via
///     `--dart-define-from-file=env.json` (siehe `tool/run-windows.ps1`;
///     `env.json` ist in `.gitignore` und wird nicht committet), und
///   * Web (GitHub Pages): über die Repo-Secrets `SUPABASE_URL` +
///     `SUPABASE_ANON_KEY`, die der Deploy-Workflow als dart-define übergibt.
///
/// Zusätzlich kann pro Gerät zur Laufzeit über „Datenbank-Verbindung ändern"
/// ein Override gesetzt werden (siehe [AppConfig]).
///
/// URL und „publishable/anon key" sind ohnehin öffentliche Client-Werte;
/// geschützt wird der Zugriff durch RLS + die E-Mail-Whitelist.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
