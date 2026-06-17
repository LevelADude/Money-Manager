import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/account.dart';

/// Zugriff auf die Tabelle `accounts` inkl. Realtime-Stream + Offline-Cache.
class AccountRepository {
  AccountRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  /// Erst der gecachte Stand (sofort/offline), dann der Live-Stream
  /// (aktualisiert + persistiert den Cache).
  Stream<List<Account>> watchAccounts() async* {
    final cached = _cache.readRows('accounts');
    if (cached.isNotEmpty) {
      yield cached
          .where((r) => r['deleted_at'] == null)
          .map(Account.fromJson)
          .toList();
    }
    try {
      yield* _client
          .from('accounts')
          .stream(primaryKey: ['id'])
          .order('created_at')
          .map((rows) {
        _cache.writeRows('accounts', rows);
        return rows
            .where((r) => r['deleted_at'] == null)
            .map(Account.fromJson)
            .toList();
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
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

  /// Soft-Delete des Kontos INKL. seiner Buchungen (sonst bleiben verwaiste
  /// Einträge übrig). Lokaler Cache wird direkt bereinigt.
  Future<void> deleteAccount(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('transactions')
        .update({'deleted_at': now}).eq('account_id', id);
    await _client
        .from('transactions')
        .update({'deleted_at': now}).eq('transfer_account_id', id);
    await _client.from('accounts').update({'deleted_at': now}).eq('id', id);
    _cache.removeFromCache('accounts', id);
    _cache.removeWhereFromCache(
      'transactions',
      (r) => r['account_id'] == id || r['transfer_account_id'] == id,
    );
  }
}
