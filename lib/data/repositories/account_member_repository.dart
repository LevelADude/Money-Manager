import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_member.dart';

/// Zugriff auf `account_members` (Mitglieder geteilter Konten). RLS: nur der
/// Besitzer eines Kontos verwaltet dessen Mitglieder; jede:r sieht die eigene
/// Mitgliedschaft.
class AccountMemberRepository {
  AccountMemberRepository(this._client);

  final SupabaseClient _client;

  /// Alle sichtbaren Mitgliedschaften (per RLS gefiltert).
  Future<List<AccountMember>> fetchAll() async {
    final rows = await _client.from('account_members').select();
    return (rows as List)
        .map((r) => AccountMember.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Setzt die Mitglieder eines Kontos exakt auf [userIds] (fügt fehlende hinzu,
  /// entfernt überzählige). Nur als Besitzer erlaubt.
  Future<void> setMembers(String accountId, Set<String> userIds) async {
    final existing = await _client
        .from('account_members')
        .select('user_id')
        .eq('account_id', accountId);
    final current = {
      for (final r in existing as List) (r as Map)['user_id'] as String,
    };
    final toAdd = userIds.difference(current);
    final toRemove = current.difference(userIds);

    if (toAdd.isNotEmpty) {
      await _client.from('account_members').insert([
        for (final u in toAdd) {'account_id': accountId, 'user_id': u},
      ]);
    }
    for (final u in toRemove) {
      await _client
          .from('account_members')
          .delete()
          .eq('account_id', accountId)
          .eq('user_id', u);
    }
  }
}
