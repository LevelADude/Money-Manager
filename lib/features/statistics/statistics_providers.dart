import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_transaction.dart';
import '../currency/currency_providers.dart';
import '../settings/settings_providers.dart';
import '../transactions/person_filter.dart';
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
  final txs = ref.watch(personFilteredTransactionsProvider);
  final convert = ref.watch(converterProvider);
  final curOf = ref.watch(accountCurrencyProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final now = DateTime.now();
  final months = [for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
  final income = {for (final m in months) _key(m): 0};
  final expense = {for (final m in months) _key(m): 0};

  for (final t in txs) {
    if (t.type == TransactionType.transfer) continue;
    final k = _key(DateTime(t.occurredOn.year, t.occurredOn.month, 1));
    if (!income.containsKey(k)) continue; // außerhalb des 12-Monats-Fensters
    final amount = convert(t.amountCents, curOf[t.accountId] ?? base);
    if (t.type == TransactionType.income) {
      income[k] = income[k]! + amount;
    } else {
      expense[k] = expense[k]! + amount;
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

/// Gesamtvermögen zum Monatsende der letzten 12 Monate (Vermögensverlauf).
final netWorthHistoryProvider =
    Provider<List<({DateTime month, int cents})>>((ref) {
  final accounts = ref.watch(personFilteredAccountsProvider);
  final txs = ref.watch(personFilteredTransactionsProvider);
  final convert = ref.watch(converterProvider);
  final now = DateTime.now();
  final result = <({DateTime month, int cents})>[];
  for (var i = 11; i >= 0; i--) {
    final monthEnd = DateTime(now.year, now.month - i + 1, 0);
    var total = 0;
    for (final a in accounts) {
      if (!a.includeInNetWorth || a.archived) continue;
      var b = a.openingBalanceCents;
      for (final t in txs) {
        if (!t.occurredOn.isAfter(monthEnd)) b += t.signedCentsFor(a.id);
      }
      total += convert(b, a.currency);
    }
    result.add((month: monthEnd, cents: total));
  }
  return result;
});

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

/// Prüft, ob [d] im Zeitfenster [r] liegt (null = "Gesamt", alles zählt).
bool _inRange(({DateTime start, DateTime end})? r, DateTime d) {
  if (r == null) return true;
  return !d.isBefore(r.start) && d.isBefore(r.end);
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
  final txs = ref.watch(personFilteredTransactionsProvider);
  final convert = ref.watch(converterProvider);
  final curOf = ref.watch(accountCurrencyProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final anchor = ref.watch(statsAnchorProvider);
  final cur = rangeFor(p, anchor, previous: false);
  final prev = rangeFor(p, anchor, previous: true);

  ({int income, int expense}) sums(({DateTime start, DateTime end})? r) {
    if (r == null) return (income: 0, expense: 0);
    var inc = 0;
    var exp = 0;
    for (final t in txs) {
      if (t.occurredOn.isBefore(r.start) || !t.occurredOn.isBefore(r.end)) {
        continue;
      }
      final amount = convert(t.amountCents, curOf[t.accountId] ?? base);
      if (t.type == TransactionType.income) inc += amount;
      if (t.type == TransactionType.expense) exp += amount;
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
  final anchor = ref.read(statsAnchorProvider);
  final range = rangeFor(p, anchor, previous: false);
  final txs = ref.read(personFilteredTransactionsProvider);
  final splitsByTx = ref.read(splitsByTransactionProvider);
  final type = expense ? TransactionType.expense : TransactionType.income;
  final result = txs.where((t) {
    if (t.type != type) return false;
    if (!_inRange(range, t.occurredOn)) return false;
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
  final anchor = ref.watch(statsAnchorProvider);
  final range = rangeFor(p, anchor, previous: false);
  final txs = ref.watch(personFilteredTransactionsProvider);
  final list = txs
      .where((t) =>
          t.type == TransactionType.expense && _inRange(range, t.occurredOn))
      .toList()
    ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
  return list.take(5).toList();
});

final statsProvider = Provider<StatsSummary>((ref) {
  final period = ref.watch(periodFilterProvider);
  final anchor = ref.watch(statsAnchorProvider);
  final range = rangeFor(period, anchor, previous: false);
  final txs = ref.watch(personFilteredTransactionsProvider);
  final accounts = ref.watch(personFilteredAccountsProvider);
  final splitsByTx = ref.watch(splitsByTransactionProvider);
  final convert = ref.watch(converterProvider);
  final curOf = ref.watch(accountCurrencyProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  String cur(AppTransaction t) => curOf[t.accountId] ?? base;

  var income = 0;
  var expense = 0;
  var count = 0;
  final expByCat = <String?, int>{};
  final incByCat = <String?, int>{};

  // Aufschlüsselung nach Kategorie (in Hauptwährung): bei aufgeteilten
  // Buchungen die Splits verwenden, sonst die eine Kategorie der Buchung.
  void addByCategory(Map<String?, int> target, AppTransaction t) {
    final code = cur(t);
    final splits = splitsByTx[t.id];
    if (splits != null && splits.isNotEmpty) {
      for (final s in splits) {
        final v = convert(s.amountCents, code);
        target.update(s.categoryId, (x) => x + v, ifAbsent: () => v);
      }
    } else {
      final v = convert(t.amountCents, code);
      target.update(t.categoryId, (x) => x + v, ifAbsent: () => v);
    }
  }

  for (final t in txs) {
    if (t.type == TransactionType.transfer) continue; // zählt nicht
    if (!_inRange(range, t.occurredOn)) continue;
    count++;
    final amount = convert(t.amountCents, cur(t));
    if (t.type == TransactionType.income) {
      income += amount;
      addByCategory(incByCat, t);
    } else {
      expense += amount;
      addByCategory(expByCat, t);
    }
  }

  // Vermögen + Schulden über alle Zeit (Salden je Konto, in Hauptwährung).
  var netWorth = 0;
  var debt = 0;
  for (final a in accounts) {
    if (a.archived) continue;
    var bal = a.openingBalanceCents;
    for (final t in txs) {
      bal += t.signedCentsFor(a.id);
    }
    final baseBal = convert(bal, a.currency);
    if (a.includeInNetWorth) netWorth += baseBal;
    if (baseBal < 0) debt += -baseBal;
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
