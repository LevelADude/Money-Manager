import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/budget.dart';

/// Zugriff auf die Tabelle `budgets` inkl. Stream + Offline-Cache.
class BudgetRepository {
  BudgetRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  Stream<List<Budget>> watchBudgets() async* {
    final cached = _cache.readRows('budgets');
    if (cached.isNotEmpty) {
      yield cached
          .where((r) => r['deleted_at'] == null)
          .map(Budget.fromJson)
          .toList();
    }
    try {
      yield* _client.from('budgets').stream(primaryKey: ['id']).map((rows) {
        _cache.writeRows('budgets', rows);
        return rows
            .where((r) => r['deleted_at'] == null)
            .map(Budget.fromJson)
            .toList();
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  /// Setzt/aktualisiert das Budget einer Kategorie (ein Budget je Kategorie).
  Future<void> setBudget({
    required String categoryId,
    required int amountCents,
  }) {
    return _client.from('budgets').upsert({
      'category_id': categoryId,
      'amount_cents': amountCents,
      'deleted_at': null,
    }, onConflict: 'category_id');
  }

  Future<void> deleteBudget(String id) {
    return _client
        .from('budgets')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
