import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/app_transaction.dart';
import '../../data/models/recurring_rule.dart';
import '../../shared/money_text.dart';
import '../recurring/recurring_providers.dart';
import '../transactions/transaction_providers.dart';

/// Planungs-Übersicht: „Verfügbar bis Monatsende" + Fixkosten (aus Daueraufträgen).
class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key});

  /// Monatlicher Gegenwert eines Dauerauftrags (Cent).
  static int _monthlyEquivalent(RecurringRule r) {
    final a = r.amountCents.toDouble();
    final c = r.intervalCount <= 0 ? 1 : r.intervalCount;
    final perMonth = switch (r.intervalUnit) {
      IntervalUnit.day => a * 365 / 12 / c,
      IntervalUnit.week => a * 52 / 12 / c,
      IntervalUnit.month => a / c,
      IntervalUnit.year => a / 12 / c,
    };
    return perMonth.round();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final txs = ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final rules = ref.watch(recurringRulesProvider).asData?.value ??
        const <RecurringRule>[];
    final df = DateFormat('dd.MM.yyyy');

    var incomeMonth = 0;
    var expenseMonth = 0;
    for (final t in txs) {
      if (t.occurredOn.year != now.year || t.occurredOn.month != now.month) {
        continue;
      }
      if (t.type == TransactionType.income) incomeMonth += t.amountCents;
      if (t.type == TransactionType.expense) expenseMonth += t.amountCents;
    }

    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final fixedExpenses =
        rules.where((r) => r.active && r.type == TransactionType.expense).toList()
          ..sort((a, b) => a.nextDue.compareTo(b.nextDue));

    var upcomingFix = 0;
    for (final r in fixedExpenses) {
      if (!r.nextDue.isBefore(today) && !r.nextDue.isAfter(lastDay)) {
        upcomingFix += r.amountCents;
      }
    }
    final available = incomeMonth - expenseMonth - upcomingFix;
    final monthlyFixTotal =
        fixedExpenses.fold<int>(0, (s, r) => s + _monthlyEquivalent(r));

    // Hochrechnung: Ausgaben-Tempo bisher auf den ganzen Monat hochgerechnet.
    final daysElapsed = now.day;
    final daysInMonth = lastDay.day;
    final projectedExpense = daysElapsed > 0
        ? (expenseMonth / daysElapsed * daysInMonth).round()
        : expenseMonth;
    final pm = DateTime(now.year, now.month - 1, 1);
    var prevMonthExpense = 0;
    for (final t in txs) {
      if (t.type == TransactionType.expense &&
          t.occurredOn.year == pm.year &&
          t.occurredOn.month == pm.month) {
        prevMonthExpense += t.amountCents;
      }
    }
    final projDeltaPct = prevMonthExpense > 0
        ? (projectedExpense - prevMonthExpense) / prevMonthExpense * 100
        : null;
    final projectedNet = incomeMonth - projectedExpense;

    return Scaffold(
      appBar: AppBar(title: const Text('Verfügbar & Fixkosten')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Verfügbar bis Monatsende',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  MoneyText(
                    available,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: available >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                  ),
                  const Divider(height: 24),
                  _line(context, 'Einnahmen (Monat)', incomeMonth),
                  _line(context, '− Ausgaben bisher', -expenseMonth),
                  _line(context, '− offene Fixkosten', -upcomingFix),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 20),
                      const SizedBox(width: 8),
                      Text('Hochrechnung Monatsende',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ausgaben voraussichtlich'),
                      MoneyText(projectedExpense,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(
                    'bei aktuellem Tempo (Tag $daysElapsed von $daysInMonth)'
                    '${projDeltaPct == null ? '' : ' · ${projDeltaPct >= 0 ? '+' : ''}${projDeltaPct.round()} % ggü. Vormonat'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Voraussichtl. Saldo'),
                      MoneyText(
                        projectedNet,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: projectedNet >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Fixkosten (monatlich)',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              MoneyText(monthlyFixTotal,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          if (fixedExpenses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Keine wiederkehrenden Ausgaben. Lege Daueraufträge unter '
                    '„Mehr → Daueraufträge" an.'),
              ),
            )
          else
            for (final r in fixedExpenses)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.repeat),
                  title: Text(r.title.isEmpty ? 'Dauerauftrag' : r.title),
                  subtitle: Text(
                      'Nächste: ${df.format(r.nextDue)} · alle '
                      '${r.intervalCount} ${r.intervalUnit.label}'),
                  trailing: MoneyText(r.amountCents,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, int cents) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          MoneyText(cents),
        ],
      ),
    );
  }
}
