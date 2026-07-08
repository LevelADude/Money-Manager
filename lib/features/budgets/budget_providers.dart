import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/budget.dart';
import '../../data/repositories/budget_repository.dart';
import '../auth/auth_providers.dart';
import '../currency/currency_providers.dart';
import '../settings/settings_providers.dart';
import '../transactions/transaction_providers.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchBudgets();
});

/// Map: Kategorie-ID -> Budget (nur Kategorie-Budgets, Gesamtbudget ausgenommen).
final budgetsByCategoryProvider = Provider<Map<String, Budget>>((ref) {
  final budgets = ref.watch(budgetsProvider).asData?.value ?? const <Budget>[];
  return {
    for (final b in budgets)
      if (b.categoryId != null) b.categoryId!: b,
  };
});

/// Das kategorieunabhängige Gesamtbudget (oder null).
final overallBudgetProvider = Provider<Budget?>((ref) {
  final budgets = ref.watch(budgetsProvider).asData?.value ?? const <Budget>[];
  for (final b in budgets) {
    if (b.isOverall) return b;
  }
  return null;
});

/// Fenster [Start, Ende) der aktuellen Periode (Woche = Mo–So, Monat).
(DateTime, DateTime) budgetPeriodWindow(BudgetPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (period == BudgetPeriod.week) {
    final start = today.subtract(Duration(days: today.weekday - 1));
    return (start, start.add(const Duration(days: 7)));
  }
  return (
    DateTime(now.year, now.month, 1),
    DateTime(now.year, now.month + 1, 1),
  );
}

/// Gesamt-Ausgaben (Cent, Hauptwährung) in der aktuellen Periode über ALLE
/// Kategorien hinweg (auch nicht kategorisierte). Für das Gesamtbudget.
final periodExpenseTotalProvider = Provider.family<int, BudgetPeriod>((
  ref,
  period,
) {
  final txs =
      ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final convert = ref.watch(converterProvider);
  final curOf = ref.watch(accountCurrencyProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final (start, end) = budgetPeriodWindow(period, DateTime.now());
  var total = 0;
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    final d = DateTime(t.occurredOn.year, t.occurredOn.month, t.occurredOn.day);
    if (d.isBefore(start) || !d.isBefore(end)) continue; // [start, end)
    total += convert(t.amountCents, curOf[t.accountId] ?? base);
  }
  return total;
});

/// Ausgaben des laufenden Monats je Kategorie (Cent). Split-bewusst: bei
/// aufgeteilten Buchungen zählen die einzelnen Split-Beträge je Kategorie.
final monthlySpentByCategoryProvider = Provider<Map<String, int>>((ref) {
  final txs =
      ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final splitsByTx = ref.watch(splitsByTransactionProvider);
  final convert = ref.watch(converterProvider);
  final curOf = ref.watch(accountCurrencyProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final now = DateTime.now();
  final map = <String, int>{};
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    if (t.occurredOn.year != now.year || t.occurredOn.month != now.month) {
      continue;
    }
    final code = curOf[t.accountId] ?? base;
    final splits = splitsByTx[t.id];
    if (splits != null && splits.isNotEmpty) {
      for (final s in splits) {
        if (s.categoryId == null) continue;
        final v = convert(s.amountCents, code);
        map.update(s.categoryId!, (x) => x + v, ifAbsent: () => v);
      }
    } else {
      final cat = t.categoryId;
      if (cat == null) continue;
      final v = convert(t.amountCents, code);
      map.update(cat, (x) => x + v, ifAbsent: () => v);
    }
  }
  return map;
});
