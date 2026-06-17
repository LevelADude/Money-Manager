import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/app_transaction.dart';

/// Zugriff auf die Tabelle `transactions` inkl. Realtime-Stream + Offline-Cache.
class TransactionRepository {
  TransactionRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  /// Erst der gecachte Stand (sofort/offline), dann der Live-Stream.
  Stream<List<AppTransaction>> watchAll() async* {
    final cached = _cache.readRows('transactions');
    if (cached.isNotEmpty) {
      yield cached
          .where((r) => r['deleted_at'] == null)
          .map(AppTransaction.fromJson)
          .toList();
    }
    try {
      yield* _client
          .from('transactions')
          .stream(primaryKey: ['id'])
          .order('occurred_on')
          .map((rows) {
        _cache.writeRows('transactions', rows);
        return rows
            .where((r) => r['deleted_at'] == null)
            .map(AppTransaction.fromJson)
            .toList();
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  Map<String, dynamic> _payload({
    required String accountId,
    required TransactionType type,
    required int amountCents,
    required DateTime occurredOn,
    required String title,
    required String note,
    String? categoryId,
    String? transferAccountId,
    String? receiptPath,
  }) {
    final isTransfer = type == TransactionType.transfer;
    return {
      'account_id': accountId,
      'type': transactionTypeToDb(type),
      'amount_cents': amountCents,
      'occurred_on': occurredOn.toIso8601String().substring(0, 10),
      'title': title,
      'note': note,
      'category_id': isTransfer ? null : categoryId,
      'transfer_account_id': isTransfer ? transferAccountId : null,
      'receipt_path': receiptPath,
    };
  }

  Future<void> addTransaction({
    required String accountId,
    required TransactionType type,
    required int amountCents,
    required DateTime occurredOn,
    String title = '',
    String note = '',
    String? categoryId,
    String? transferAccountId,
    String? receiptPath,
  }) {
    return _client.from('transactions').insert(_payload(
          accountId: accountId,
          type: type,
          amountCents: amountCents,
          occurredOn: occurredOn,
          title: title,
          note: note,
          categoryId: categoryId,
          transferAccountId: transferAccountId,
          receiptPath: receiptPath,
        ));
  }

  Future<void> updateTransaction({
    required String id,
    required String accountId,
    required TransactionType type,
    required int amountCents,
    required DateTime occurredOn,
    String title = '',
    String note = '',
    String? categoryId,
    String? transferAccountId,
    String? receiptPath,
  }) {
    return _client
        .from('transactions')
        .update(_payload(
          accountId: accountId,
          type: type,
          amountCents: amountCents,
          occurredOn: occurredOn,
          title: title,
          note: note,
          categoryId: categoryId,
          transferAccountId: transferAccountId,
          receiptPath: receiptPath,
        ))
        .eq('id', id);
  }

  /// Soft-Delete (Tombstone).
  Future<void> deleteTransaction(String id) {
    return _client
        .from('transactions')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Zuletzt verwendete Titel (für Autovervollständigung).
  Future<List<String>> recentTitles({int limit = 50}) async {
    final rows = await _client
        .from('transactions')
        .select('title, created_at')
        .neq('title', '')
        .order('created_at', ascending: false)
        .limit(300);
    final seen = <String>{};
    for (final r in rows as List) {
      final t = (r as Map)['title'] as String?;
      if (t != null && t.trim().isNotEmpty) seen.add(t);
      if (seen.length >= limit) break;
    }
    return seen.toList();
  }
}
