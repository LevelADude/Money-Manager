import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/transaction_split.dart';

/// Zugriff auf die Tabelle `transaction_splits` (Aufteilungen einer Buchung)
/// inkl. Realtime-Stream + Offline-Cache.
class SplitRepository {
  SplitRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  /// Erst der gecachte Stand (sofort/offline), dann der Live-Stream.
  Stream<List<TransactionSplit>> watchAll() async* {
    final cached = _cache.readRows('transaction_splits');
    if (cached.isNotEmpty) {
      yield cached.map(TransactionSplit.fromJson).toList();
    }
    try {
      yield* _client
          .from('transaction_splits')
          .stream(primaryKey: ['id']).map((rows) {
        _cache.writeRows('transaction_splits', rows);
        return rows.map(TransactionSplit.fromJson).toList();
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  /// Ersetzt alle Aufteilungen einer Buchung (löscht vorhandene, legt neue an).
  /// [splits] enthält Paare aus (categoryId, amountCents, note).
  Future<void> replaceForTransaction(
    String transactionId,
    List<({String? categoryId, int amountCents, String note})> splits,
  ) async {
    await _client
        .from('transaction_splits')
        .delete()
        .eq('transaction_id', transactionId);
    _cache.removeWhereFromCache(
        'transaction_splits', (r) => r['transaction_id'] == transactionId);
    if (splits.isEmpty) return;
    await _client.from('transaction_splits').insert([
      for (final s in splits)
        {
          'transaction_id': transactionId,
          'category_id': s.categoryId,
          'amount_cents': s.amountCents,
          'note': s.note,
        },
    ]);
  }

  Future<void> deleteForTransaction(String transactionId) async {
    await _client
        .from('transaction_splits')
        .delete()
        .eq('transaction_id', transactionId);
    _cache.removeWhereFromCache(
        'transaction_splits', (r) => r['transaction_id'] == transactionId);
  }
}
