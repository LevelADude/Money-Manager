import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// Zugriff auf die Tabelle `profiles` (Namen der Mitglieder).
///
/// `profiles` ist bewusst nicht in der Realtime-Publication – Namen ändern sich
/// selten, daher reicht eine Einmal-Abfrage (Provider kann invalidiert werden).
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<List<Profile>> fetchProfiles() async {
    final rows = await _client.from('profiles').select();
    return (rows as List)
        .map((r) => Profile.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<bool> fetchIsAdmin() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client
        .from('profiles')
        .select('is_admin')
        .eq('id', uid)
        .maybeSingle();
    return (row?['is_admin'] as bool?) ?? false;
  }

  Future<bool> fetchIsReadOnly() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client
        .from('profiles')
        .select('read_only')
        .eq('id', uid)
        .maybeSingle();
    return (row?['read_only'] as bool?) ?? false;
  }

  Future<String> fetchMyDisplayName() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return '';
    final row = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', uid)
        .maybeSingle();
    return (row?['display_name'] as String?) ?? '';
  }

  Future<void> updateMyDisplayName(String name) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('profiles')
        .update({'display_name': name}).eq('id', uid);
  }
}
