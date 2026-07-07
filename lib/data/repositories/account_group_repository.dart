import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_group.dart';

/// Zugriff auf die Tabelle `account_groups` (eigene Konten-Gruppen für
/// Custom-Summen). RLS liefert nur die eigenen Gruppen.
class AccountGroupRepository {
  AccountGroupRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<List<AccountGroup>> fetchAll() async {
    final rows = await _client
        .from('account_groups')
        .select()
        .order('sort_order');
    return (rows as List)
        .map((r) => AccountGroup.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> create(String name, List<String> accountIds) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('account_groups').insert({
      'owner_id': uid,
      'name': name.trim(),
      'account_ids': accountIds,
    });
  }

  Future<void> update(String id, String name, List<String> accountIds) async {
    await _client
        .from('account_groups')
        .update({'name': name.trim(), 'account_ids': accountIds})
        .eq('id', id);
  }

  Future<void> remove(String id) async {
    await _client.from('account_groups').delete().eq('id', id);
  }
}
