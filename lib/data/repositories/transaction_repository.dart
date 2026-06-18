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
    List<String> tags = const [],
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
      'tags': tags,
    };
  }

  /// Legt eine Buchung an und gibt deren neue ID zurück (für Splits/Belege).
  Future<String> addTransaction({
    required String accountId,
    required TransactionType type,
    required int amountCents,
    required DateTime occurredOn,
    String title = '',
    String note = '',
    String? categoryId,
    String? transferAccountId,
    String? receiptPath,
    List<String> tags = const [],
  }) async {
    final row = await _client
        .from('transactions')
        .insert(_payload(
          accountId: accountId,
          type: type,
          amountCents: amountCents,
          occurredOn: occurredOn,
          title: title,
          note: note,
          categoryId: categoryId,
          transferAccountId: transferAccountId,
          receiptPath: receiptPath,
          tags: tags,
        ))
        .select('id')
        .single();
    return row['id'] as String;
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
    List<String> tags = const [],
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
          tags: tags,
        ))
        .eq('id', id);
  }

  /// Soft-Delete (Tombstone) + sofort aus dem lokalen Cache entfernen.
  Future<void> deleteTransaction(String id) async {
    await _client
        .from('transactions')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
    _cache.removeFromCache('transactions', id);
  }

  /// Gelöschte (Tombstone-)Buchungen für den Papierkorb, neueste zuerst.
  Future<List<({AppTransaction tx, DateTime deletedAt})>>
      deletedTransactions() async {
    final rows = await _client
        .from('transactions')
        .select()
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false)
        .limit(200);
    return [
      for (final r in rows as List)
        (
          tx: AppTransaction.fromJson(r as Map<String, dynamic>),
          deletedAt: DateTime.parse((r)['deleted_at'] as String),
        ),
    ];
  }

  /// Stellt eine gelöschte Buchung wieder her.
  Future<void> restoreTransaction(String id) async {
    await _client.from('transactions').update({'deleted_at': null}).eq('id', id);
  }

  /// Entfernt eine Buchung endgültig (inkl. Splits via FK-Cascade).
  Future<void> purgeTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
    _cache.removeFromCache('transactions', id);
  }

  /// Räumt Tombstones auf, die älter als [age] sind (endgültig).
  Future<void> purgeOlderThan(Duration age) async {
    final cutoff = DateTime.now().toUtc().subtract(age).toIso8601String();
    await _client
        .from('transactions')
        .delete()
        .not('deleted_at', 'is', null)
        .lt('deleted_at', cutoff);
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
