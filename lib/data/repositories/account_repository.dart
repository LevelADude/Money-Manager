import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account.dart';

/// Zugriff auf die Tabelle `accounts` inkl. Realtime-Stream.
class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Account>> watchAccounts() {
    return _client
        .from('accounts')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows
            .where((r) => r['deleted_at'] == null)
            .map(Account.fromJson)
            .toList());
  }

  Future<void> createAccount({
    required String name,
    required AccountType type,
    String currency = 'EUR',
    int openingBalanceCents = 0,
    String? icon,
    int? color,
    int? creditLimitCents,
    bool includeInNetWorth = true,
  }) {
    return _client.from('accounts').insert({
      'name': name,
      'type': accountTypeToDb(type),
      'currency': currency,
      'opening_balance_cents': openingBalanceCents,
      'icon': icon,
      'color': color,
      'credit_limit_cents': creditLimitCents,
      'include_in_net_worth': includeInNetWorth,
    });
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required AccountType type,
    required int openingBalanceCents,
    required bool includeInNetWorth,
    String? icon,
    int? color,
    int? creditLimitCents,
  }) {
    return _client.from('accounts').update({
      'name': name,
      'type': accountTypeToDb(type),
      'opening_balance_cents': openingBalanceCents,
      'include_in_net_worth': includeInNetWorth,
      'icon': icon,
      'color': color,
      'credit_limit_cents': creditLimitCents,
    }).eq('id', id);
  }

  Future<void> setArchived({required String id, required bool archived}) {
    return _client.from('accounts').update({'archived': archived}).eq('id', id);
  }

  /// Soft-Delete (Tombstone) – für Local-First-Sync.
  Future<void> deleteAccount(String id) {
    return _client
        .from('accounts')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
