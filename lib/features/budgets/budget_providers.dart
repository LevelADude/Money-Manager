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
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  return {
    for (final b in budgets)
      if (b.categoryId != null) b.categoryId!: b,
  };
});

/// Das kategorieunabhängige Gesamtbudget (oder null).
final overallBudgetProvider = Provider<Budget?>((ref) {
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  for (final b in budgets) {
    if (b.isOverall) return b;
  }
  return null;
});

/// Der Zeitraum, der für ALLE Budgets gilt: der des Gesamtbudgets, sonst Monat.
/// Kategorie-Budgets teilen sich bewusst den Zeitraum des Gesamtbudgets – nur
/// so lassen sich die Teilbudgets sinnvoll gegen das Gesamtbudget rechnen.
final budgetPeriodProvider = Provider<BudgetPeriod>((ref) {
  return ref.watch(overallBudgetProvider)?.period ?? BudgetPeriod.month;
});

/// Summe der bereits auf Kategorien verteilten Budgets (Cent).
final allocatedBudgetCentsProvider = Provider<int>((ref) {
  final byCat = ref.watch(budgetsByCategoryProvider);
  var sum = 0;
  for (final b in byCat.values) {
    sum += b.amountCents;
  }
  return sum;
});

/// Wie viel vom Gesamtbudget noch auf Kategorien verteilt werden kann (Cent).
/// Negativ = mehr verplant als vorhanden. `null` = kein Gesamtbudget gesetzt.
final unallocatedBudgetCentsProvider = Provider<int?>((ref) {
  final overall = ref.watch(overallBudgetProvider);
  if (overall == null) return null;
  return overall.amountCents - ref.watch(allocatedBudgetCentsProvider);
});

/// Prüft, ob ein neues/geändertes Kategorie-Budget die Aufteilung des
/// Gesamtbudgets sprengt. [allocatedOtherCents] ist die Summe der ANDEREN
/// Kategorie-Budgets (das eigene alte also bereits abgezogen).
///
/// Ohne Gesamtbudget ([overallCents] == null) gibt es keine Obergrenze.
({bool exceeds, int planned, int overBy}) checkAllocation({
  required int? overallCents,
  required int allocatedOtherCents,
  required int newCents,
}) {
  final planned = allocatedOtherCents + newCents;
  if (overallCents == null || planned <= overallCents) {
    return (exceeds: false, planned: planned, overBy: 0);
  }
  return (exceeds: true, planned: planned, overBy: planned - overallCents);
}

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
      ref.watch(allTransactionsProvider).value ?? const <AppTransaction>[];
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

/// Ausgaben der laufenden Periode je Kategorie (Cent). Split-bewusst: bei
/// aufgeteilten Buchungen zählen die einzelnen Split-Beträge je Kategorie.
final spentByCategoryProvider = Provider.family<Map<String, int>, BudgetPeriod>(
  (ref, period) {
    final txs =
        ref.watch(allTransactionsProvider).value ?? const <AppTransaction>[];
    final splitsByTx = ref.watch(splitsByTransactionProvider);
    final convert = ref.watch(converterProvider);
    final curOf = ref.watch(accountCurrencyProvider);
    final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
    final (start, end) = budgetPeriodWindow(period, DateTime.now());
    final map = <String, int>{};
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      final d = DateTime(
        t.occurredOn.year,
        t.occurredOn.month,
        t.occurredOn.day,
      );
      if (d.isBefore(start) || !d.isBefore(end)) continue; // [start, end)
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
  },
);

/// Ausgaben des laufenden Monats je Kategorie – für die Monats-Auswertungen
/// (Insights), die unabhängig vom gewählten Budget-Zeitraum monatlich denken.
final monthlySpentByCategoryProvider = Provider<Map<String, int>>((ref) {
  return ref.watch(spentByCategoryProvider(BudgetPeriod.month));
});
