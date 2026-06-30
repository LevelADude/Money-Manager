import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-Aktionen: Whitelist verwalten, Admin-Rechte setzen, Nutzer löschen.
class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<List<String>> fetchAllowedEmails() async {
    final rows = await _client
        .from('allowed_emails')
        .select('email')
        .order('email');
    return (rows as List).map((r) => (r as Map)['email'] as String).toList();
  }

  Future<void> addAllowedEmail(String email) {
    return _client.from('allowed_emails').insert({
      'email': email.trim().toLowerCase(),
    });
  }

  Future<void> removeAllowedEmail(String email) {
    return _client.from('allowed_emails').delete().eq('email', email);
  }

  Future<void> setAdmin({required String profileId, required bool value}) {
    return _client
        .from('profiles')
        .update({'is_admin': value})
        .eq('id', profileId);
  }

  Future<void> setReadOnly({required String profileId, required bool value}) {
    return _client
        .from('profiles')
        .update({'read_only': value})
        .eq('id', profileId);
  }

  /// Löscht ein Auth-Konto über die Edge Function (service_role serverseitig).
  Future<void> deleteUser(String userId) async {
    final res = await _client.functions.invoke(
      'admin-delete-user',
      body: {'userId': userId},
    );
    _ensureOk(res);
  }

  /// Aktuelle Speichernutzung (Datenbank + Datei-Speicher) in Bytes.
  Future<({int dbBytes, int storageBytes})> fetchStorageStats() async {
    final rows = await _client.rpc('get_storage_stats');
    final row = (rows is List && rows.isNotEmpty)
        ? rows.first as Map
        : const {};
    return (
      dbBytes: (row['db_bytes'] as num?)?.toInt() ?? 0,
      storageBytes: (row['storage_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Leert alle Finanzdaten (Nutzer/Rollen/Whitelist bleiben). Nur Admins.
  Future<void> wipeData() async {
    final res = await _client.functions.invoke('admin-wipe-data');
    _ensureOk(res);
  }

  /// Setzt das gesamte Projekt auf Werkseinstellungen zurück (alles inkl. aller
  /// Nutzer). Nur der Besitzer. Der Aufrufer wird danach ausgeloggt.
  Future<void> factoryReset() async {
    final res = await _client.functions.invoke('admin-factory-reset');
    _ensureOk(res);
  }

  /// Wirft eine aussagekräftige Exception, falls eine Edge Function != 200 war.
  void _ensureOk(FunctionResponse res) {
    if (res.status != 200) {
      final data = res.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Fehler ${res.status}';
      throw Exception(msg);
    }
  }
}
