import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/budget.dart' show Budget, BudgetPeriod, budgetPeriodToDb;

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
        final unique = dedupRowsById(rows);
        _cache.writeRows('budgets', unique);
        return unique
            .where((r) => r['deleted_at'] == null)
            .map(Budget.fromJson)
            .toList();
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  /// Setzt/aktualisiert das Budget einer Kategorie. Vorhandenes Budget wird
  /// über [existingId] aktualisiert, sonst neu angelegt. [period] ist immer der
  /// Zeitraum des Gesamtbudgets – nur mit einem gemeinsamen Zeitraum lassen
  /// sich die Kategorie-Budgets gegen das Gesamtbudget rechnen.
  Future<void> setCategoryBudget({
    required String categoryId,
    required int amountCents,
    required BudgetPeriod period,
    String? existingId,
  }) {
    if (existingId != null) {
      return _client
          .from('budgets')
          .update({
            'amount_cents': amountCents,
            'period': budgetPeriodToDb(period),
            'deleted_at': null,
          })
          .eq('id', existingId);
    }
    return _client.from('budgets').insert({
      'category_id': categoryId,
      'amount_cents': amountCents,
      'period': budgetPeriodToDb(period),
    });
  }

  /// Zieht alle eigenen Kategorie-Budgets auf [period] nach – wird aufgerufen,
  /// wenn der Zeitraum des Gesamtbudgets gewechselt wird.
  Future<void> setPeriodForAllCategoryBudgets(BudgetPeriod period) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('budgets')
        .update({'period': budgetPeriodToDb(period)})
        .eq('created_by', uid)
        .isFilter('deleted_at', null)
        .not('category_id', 'is', null);
  }

  /// Setzt/aktualisiert das kategorieunabhängige Gesamtbudget (Monat/Woche).
  Future<void> setOverallBudget({
    required BudgetPeriod period,
    required int amountCents,
    String? existingId,
  }) {
    if (existingId != null) {
      return _client
          .from('budgets')
          .update({
            'amount_cents': amountCents,
            'period': budgetPeriodToDb(period),
            'deleted_at': null,
          })
          .eq('id', existingId);
    }
    return _client.from('budgets').insert({
      'category_id': null,
      'amount_cents': amountCents,
      'period': budgetPeriodToDb(period),
    });
  }

  Future<void> deleteBudget(String id) {
    return _client
        .from('budgets')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
