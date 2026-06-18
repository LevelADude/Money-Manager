import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../accounts/account_providers.dart';
import '../transactions/transaction_providers.dart';
import 'period_filter.dart';

/// Aggregierte Auswertung für den gewählten Zeitraum. Wird vollständig lokal
/// aus den bereits geladenen Daten berechnet (kein zusätzlicher Traffic).
class StatsSummary {
  const StatsSummary({
    required this.incomeCents,
    required this.expenseCents,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.debtCents,
    required this.netWorthCents,
    required this.txCount,
  });

  final int incomeCents;
  final int expenseCents;
  final Map<String?, int> expenseByCategory;
  final Map<String?, int> incomeByCategory;
  final int debtCents;
  final int netWorthCents;
  final int txCount;

  int get balanceCents => incomeCents - expenseCents;
}

/// Summen je Monat (für den Monatstrend, unabhängig vom gewählten Zeitraum).
class MonthTotals {
  const MonthTotals({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  final DateTime month; // erster Tag des Monats
  final int incomeCents;
  final int expenseCents;

  int get netCents => incomeCents - expenseCents;
}

/// Einnahmen/Ausgaben der letzten 12 Monate (ältester zuerst).
final monthlyTotalsProvider = Provider<List<MonthTotals>>((ref) {
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final now = DateTime.now();
  final months = [for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
  final income = {for (final m in months) _key(m): 0};
  final expense = {for (final m in months) _key(m): 0};

  for (final t in txs) {
    if (t.type == TransactionType.transfer) continue;
    final k = _key(DateTime(t.occurredOn.year, t.occurredOn.month, 1));
    if (!income.containsKey(k)) continue; // außerhalb des 12-Monats-Fensters
    if (t.type == TransactionType.income) {
      income[k] = income[k]! + t.amountCents;
    } else {
      expense[k] = expense[k]! + t.amountCents;
    }
  }

  return [
    for (final m in months)
      MonthTotals(
        month: m,
        incomeCents: income[_key(m)]!,
        expenseCents: expense[_key(m)]!,
      ),
  ];
});

String _key(DateTime m) => '${m.year}-${m.month}';

/// Zeitfenster (start inкl., end exkl.) des aktuellen bzw. vorherigen Zeitraums.
({DateTime start, DateTime end})? rangeFor(StatsPeriod p, DateTime now,
    {required bool previous}) {
  switch (p) {
    case StatsPeriod.thisDay:
      final base = DateTime(now.year, now.month, now.day)
          .add(Duration(days: previous ? -1 : 0));
      return (start: base, end: base.add(const Duration(days: 1)));
    case StatsPeriod.thisWeek:
      final today = DateTime(now.year, now.month, now.day);
      final startThis = today.subtract(Duration(days: today.weekday - 1));
      final start = startThis.add(Duration(days: previous ? -7 : 0));
      return (start: start, end: start.add(const Duration(days: 7)));
    case StatsPeriod.thisMonth:
      final m = DateTime(now.year, now.month + (previous ? -1 : 0), 1);
      return (start: m, end: DateTime(m.year, m.month + 1, 1));
    case StatsPeriod.thisYear:
      final y = DateTime(now.year + (previous ? -1 : 0), 1, 1);
      return (start: y, end: DateTime(y.year + 1, 1, 1));
    case StatsPeriod.all:
      return null;
  }
}

/// Vergleich des gewählten Zeitraums mit dem vorherigen (Vortag/-woche/-monat/-jahr).
class PeriodComparison {
  const PeriodComparison({
    required this.curExpense,
    required this.prevExpense,
    required this.curIncome,
    required this.prevIncome,
    required this.hasPrevious,
    required this.prevLabel,
  });

  final int curExpense;
  final int prevExpense;
  final int curIncome;
  final int prevIncome;
  final bool hasPrevious;
  final String prevLabel;

  /// Veränderung Ausgaben in Prozent (null wenn kein Vorwert).
  double? get expenseDeltaPct =>
      prevExpense == 0 ? null : (curExpense - prevExpense) / prevExpense * 100;
  double? get incomeDeltaPct =>
      prevIncome == 0 ? null : (curIncome - prevIncome) / prevIncome * 100;
}

final periodComparisonProvider = Provider<PeriodComparison>((ref) {
  final p = ref.watch(periodFilterProvider);
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final now = DateTime.now();
  final cur = rangeFor(p, now, previous: false);
  final prev = rangeFor(p, now, previous: true);

  ({int income, int expense}) sums(({DateTime start, DateTime end})? r) {
    if (r == null) return (income: 0, expense: 0);
    var inc = 0;
    var exp = 0;
    for (final t in txs) {
      if (t.occurredOn.isBefore(r.start) || !t.occurredOn.isBefore(r.end)) {
        continue;
      }
      if (t.type == TransactionType.income) inc += t.amountCents;
      if (t.type == TransactionType.expense) exp += t.amountCents;
    }
    return (income: inc, expense: exp);
  }

  final c = sums(cur);
  final pv = sums(prev);
  final label = switch (p) {
    StatsPeriod.thisDay => 'Vortag',
    StatsPeriod.thisWeek => 'Vorwoche',
    StatsPeriod.thisMonth => 'Vormonat',
    StatsPeriod.thisYear => 'Vorjahr',
    StatsPeriod.all => '',
  };

  return PeriodComparison(
    curExpense: c.expense,
    prevExpense: pv.expense,
    curIncome: c.income,
    prevIncome: pv.income,
    hasPrevious: prev != null,
    prevLabel: label,
  );
});

/// Buchungen einer Kategorie im gewählten Zeitraum (für Drill-down).
/// [expense] = true: Ausgaben, sonst Einnahmen. [categoryId] null = "Ohne".
List<AppTransaction> categoryDrilldown(
  WidgetRef ref, {
  required String? categoryId,
  required bool expense,
}) {
  final p = ref.read(periodFilterProvider);
  final txs = ref.read(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final splitsByTx = ref.read(splitsByTransactionProvider);
  final type = expense ? TransactionType.expense : TransactionType.income;
  final result = txs.where((t) {
    if (t.type != type) return false;
    if (!p.contains(t.occurredOn)) return false;
    final splits = splitsByTx[t.id];
    if (splits != null && splits.isNotEmpty) {
      return splits.any((s) => s.categoryId == categoryId);
    }
    return t.categoryId == categoryId;
  }).toList()
    ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
  return result;
}

/// Größte Einzel-Ausgaben im gewählten Zeitraum.
final topExpensesProvider = Provider<List<AppTransaction>>((ref) {
  final p = ref.watch(periodFilterProvider);
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final list = txs
      .where((t) => t.type == TransactionType.expense && p.contains(t.occurredOn))
      .toList()
    ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
  return list.take(5).toList();
});

final statsProvider = Provider<StatsSummary>((ref) {
  final period = ref.watch(periodFilterProvider);
  final txs = ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final accounts =
      ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final splitsByTx = ref.watch(splitsByTransactionProvider);

  var income = 0;
  var expense = 0;
  var count = 0;
  final expByCat = <String?, int>{};
  final incByCat = <String?, int>{};

  // Aufschlüsselung nach Kategorie: bei aufgeteilten Buchungen die Splits
  // verwenden, sonst die eine Kategorie der Buchung.
  void addByCategory(Map<String?, int> target, AppTransaction t) {
    final splits = splitsByTx[t.id];
    if (splits != null && splits.isNotEmpty) {
      for (final s in splits) {
        target.update(s.categoryId, (v) => v + s.amountCents,
            ifAbsent: () => s.amountCents);
      }
    } else {
      target.update(t.categoryId, (v) => v + t.amountCents,
          ifAbsent: () => t.amountCents);
    }
  }

  for (final t in txs) {
    if (t.type == TransactionType.transfer) continue; // zählt nicht
    if (!period.contains(t.occurredOn)) continue;
    count++;
    if (t.type == TransactionType.income) {
      income += t.amountCents;
      addByCategory(incByCat, t);
    } else {
      expense += t.amountCents;
      addByCategory(expByCat, t);
    }
  }

  // Vermögen + Schulden über alle Zeit (Salden je Konto).
  var netWorth = 0;
  var debt = 0;
  for (final a in accounts) {
    if (a.archived) continue;
    var bal = a.openingBalanceCents;
    for (final t in txs) {
      bal += t.signedCentsFor(a.id);
    }
    if (a.includeInNetWorth) netWorth += bal;
    if (bal < 0) debt += -bal;
  }

  return StatsSummary(
    incomeCents: income,
    expenseCents: expense,
    expenseByCategory: expByCat,
    incomeByCategory: incByCat,
    debtCents: debt,
    netWorthCents: netWorth,
    txCount: count,
  );
});
