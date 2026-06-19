import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/access_grant.dart';

/// Zugriff auf `access_grants` (wer darf auf wessen Finanzen zugreifen).
/// RLS stellt sicher, dass man nur eigene Freigaben anlegt/ändert und nur
/// Freigaben sieht, an denen man beteiligt ist.
class AccessGrantRepository {
  AccessGrantRepository(this._client);

  final SupabaseClient _client;

  /// Alle Freigaben, an denen der aktuelle Nutzer beteiligt ist (als Besitzer
  /// oder als Begünstigter) – per RLS gefiltert.
  Future<List<AccessGrant>> fetchAll() async {
    final rows = await _client.from('access_grants').select();
    return (rows as List)
        .map((r) => AccessGrant.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Legt eine Freigabe an oder ändert ihre Stufe (eine je Begünstigtem).
  Future<void> grant(String granteeId, GrantLevel level) {
    final me = _client.auth.currentUser!.id;
    return _client.from('access_grants').upsert({
      'owner_id': me,
      'grantee_id': granteeId,
      'level': grantLevelToDb(level),
    }, onConflict: 'owner_id,grantee_id');
  }

  /// Entzieht einer Person den Zugriff auf die eigenen Finanzen.
  Future<void> revoke(String granteeId) {
    final me = _client.auth.currentUser!.id;
    return _client
        .from('access_grants')
        .delete()
        .eq('owner_id', me)
        .eq('grantee_id', granteeId);
  }
}
