import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/app_transaction.dart';
import '../models/transaction_template.dart';

/// Zugriff auf die Tabelle `transaction_templates` (Buchungs-Vorlagen).
class TemplateRepository {
  TemplateRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  Stream<List<TransactionTemplate>> watchAll() async* {
    final cached = _cache.readRows('transaction_templates');
    if (cached.isNotEmpty) {
      yield cached.map(TransactionTemplate.fromJson).toList();
    }
    try {
      yield* _client
          .from('transaction_templates')
          .stream(primaryKey: ['id'])
          .order('name')
          .map((rows) {
        _cache.writeRows('transaction_templates', rows);
        return rows.map(TransactionTemplate.fromJson).toList();
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  Future<void> add({
    required String name,
    required String? accountId,
    required TransactionType type,
    required int amountCents,
    required String? categoryId,
    required String title,
    required String note,
    required List<String> tags,
  }) {
    return _client.from('transaction_templates').insert({
      'name': name,
      'account_id': accountId,
      'type': transactionTypeToDb(type),
      'amount_cents': amountCents,
      'category_id': categoryId,
      'title': title,
      'note': note,
      'tags': tags,
    });
  }

  Future<void> delete(String id) async {
    await _client.from('transaction_templates').delete().eq('id', id);
    _cache.removeFromCache('transaction_templates', id);
  }
}
