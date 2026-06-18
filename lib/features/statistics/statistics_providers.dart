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
