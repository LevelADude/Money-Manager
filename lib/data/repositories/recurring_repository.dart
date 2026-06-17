import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/app_transaction.dart';
import '../models/recurring_rule.dart';

/// Zugriff auf `recurring_rules` + race-sichere Generierung fälliger Buchungen.
class RecurringRepository {
  RecurringRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  static String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  Stream<List<RecurringRule>> watchRules() async* {
    final cached = _cache.readRows('recurring_rules');
    if (cached.isNotEmpty) {
      yield cached
          .where((r) => r['deleted_at'] == null)
          .map(RecurringRule.fromJson)
          .toList();
    }
    try {
      yield* _client
          .from('recurring_rules')
          .stream(primaryKey: ['id'])
          .order('next_due')
          .map((rows) {
        _cache.writeRows('recurring_rules', rows);
        return rows
            .where((r) => r['deleted_at'] == null)
            .map(RecurringRule.fromJson)
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
    required String? categoryId,
    required String? transferAccountId,
    required String title,
    required String note,
    required IntervalUnit intervalUnit,
    required int intervalCount,
    required DateTime nextDue,
    required DateTime? endDate,
    required bool active,
  }) {
    final isTransfer = type == TransactionType.transfer;
    return {
      'account_id': accountId,
      'type': transactionTypeToDb(type),
      'amount_cents': amountCents,
      'category_id': isTransfer ? null : categoryId,
      'transfer_account_id': isTransfer ? transferAccountId : null,
      'title': title,
      'note': note,
      'interval_unit': intervalUnitToDb(intervalUnit),
      'interval_count': intervalCount,
      'next_due': _d(nextDue),
      'end_date': endDate == null ? null : _d(endDate),
      'active': active,
    };
  }

  Future<void> createRule({
    required String accountId,
    required TransactionType type,
    required int amountCents,
    String? categoryId,
    String? transferAccountId,
    String title = '',
    String note = '',
    required IntervalUnit intervalUnit,
    int intervalCount = 1,
    required DateTime nextDue,
    DateTime? endDate,
  }) {
    return _client.from('recurring_rules').insert(_payload(
          accountId: accountId,
          type: type,
          amountCents: amountCents,
          categoryId: categoryId,
          transferAccountId: transferAccountId,
          title: title,
          note: note,
          intervalUnit: intervalUnit,
          intervalCount: intervalCount,
          nextDue: nextDue,
          endDate: endDate,
          active: true,
        ));
  }

  Future<void> updateRule({
    required String id,
    required String accountId,
    required TransactionType type,
    required int amountCents,
    String? categoryId,
    String? transferAccountId,
    String title = '',
    String note = '',
    required IntervalUnit intervalUnit,
    int intervalCount = 1,
    required DateTime nextDue,
    DateTime? endDate,
    required bool active,
  }) {
    return _client
        .from('recurring_rules')
        .update(_payload(
          accountId: accountId,
          type: type,
          amountCents: amountCents,
          categoryId: categoryId,
          transferAccountId: transferAccountId,
          title: title,
          note: note,
          intervalUnit: intervalUnit,
          intervalCount: intervalCount,
          nextDue: nextDue,
          endDate: endDate,
          active: active,
        ))
        .eq('id', id);
  }

  Future<void> setActive({required String id, required bool active}) {
    return _client
        .from('recurring_rules')
        .update({'active': active}).eq('id', id);
  }

  Future<void> deleteRule(String id) {
    return _client
        .from('recurring_rules')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Erzeugt alle fälligen Buchungen. **Race-sicher**: vor dem Anlegen wird die
  /// Periode atomar beansprucht (`next_due` von alt auf neu setzen, nur wenn der
  /// alte Wert noch stimmt). Gewinnt nur ein Gerät → keine Doppelbuchungen.
  Future<int> generateDue() async {
    try {
      final today = DateTime.now();
      final todayStr = _d(DateTime(today.year, today.month, today.day));
      final rows = await _client
          .from('recurring_rules')
          .select()
          .eq('active', true)
          .lte('next_due', todayStr)
          .isFilter('deleted_at', null);

      var created = 0;
      for (final raw in rows as List) {
        final rule = RecurringRule.fromJson(raw as Map<String, dynamic>);
        var current = rule.nextDue;
        var guard = 0;
        while (!current.isAfter(today) && guard < 1000) {
          guard++;
          if (rule.endDate != null && current.isAfter(rule.endDate!)) {
            await _client
                .from('recurring_rules')
                .update({'active': false}).eq('id', rule.id);
            break;
          }
          final newDue =
              advanceDate(current, rule.intervalUnit, rule.intervalCount);
          final claimed = await _client
              .from('recurring_rules')
              .update({'next_due': _d(newDue)})
              .eq('id', rule.id)
              .eq('next_due', _d(current))
              .isFilter('deleted_at', null)
              .select();
          if ((claimed as List).isEmpty) break; // anderes Gerät war schneller
          await _client.from('transactions').insert({
            'account_id': rule.accountId,
            'type': transactionTypeToDb(rule.type),
            'amount_cents': rule.amountCents,
            'occurred_on': _d(current),
            'category_id':
                rule.type == TransactionType.transfer ? null : rule.categoryId,
            'transfer_account_id': rule.type == TransactionType.transfer
                ? rule.transferAccountId
                : null,
            'title': rule.title,
            'note': rule.note,
          });
          created++;
          current = newDue;
        }
      }
      return created;
    } catch (_) {
      return 0; // offline oder Fehler: nichts erzeugt
    }
  }
}
