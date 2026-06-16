import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_transaction.dart';

/// Zugriff auf die Tabelle `transactions` inkl. Realtime-Stream.
class TransactionRepository {
  TransactionRepository(this._client);

  final SupabaseClient _client;

  /// Live-Stream der Buchungen eines Buchs.
  Stream<List<AppTransaction>> watchTransactions(String ledgerId) {
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('ledger_id', ledgerId)
        .order('occurred_on')
        .map((rows) => rows.map(AppTransaction.fromJson).toList());
  }

  Future<void> addTransaction({
    required String ledgerId,
    required TransactionDirection direction,
    required double amount,
    required DateTime occurredOn,
    String note = '',
    String? categoryId,
  }) {
    return _client.from('transactions').insert({
      'ledger_id': ledgerId,
      'direction':
          direction == TransactionDirection.income ? 'income' : 'expense',
      'amount': amount,
      // Nur das Datum (YYYY-MM-DD) für die `date`-Spalte.
      'occurred_on': occurredOn.toIso8601String().substring(0, 10),
      'note': note,
      'category_id': categoryId, // Spalte ist nullable
    });
  }

  Future<void> deleteTransaction(String id) {
    return _client.from('transactions').delete().eq('id', id);
  }
}
