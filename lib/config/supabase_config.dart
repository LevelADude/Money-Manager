/// Supabase-Zugangsdaten.
///
/// Werden zur Laufzeit über `--dart-define-from-file=env.json` gesetzt
/// (siehe env.example.json). So landen keine Secrets im Quellcode.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
