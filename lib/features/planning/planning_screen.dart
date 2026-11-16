import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/app_transaction.dart';
import '../../data/models/recurring_rule.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money_text.dart';
import '../recurring/recurring_providers.dart';
import '../transactions/transaction_providers.dart';
import '../../core/theme.dart';
import '../../shared/bento.dart';

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
    final txs =
        ref.watch(allTransactionsProvider).value ?? const <AppTransaction>[];
    final rules =
        ref.watch(recurringRulesProvider).value ?? const <RecurringRule>[];
    final l = AppLocalizations.of(context);
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
        rules
            .where((r) => r.active && r.type == TransactionType.expense)
            .toList()
          ..sort((a, b) => a.nextDue.compareTo(b.nextDue));

    var upcomingFix = 0;
    for (final r in fixedExpenses) {
      if (!r.nextDue.isBefore(today) && !r.nextDue.isAfter(lastDay)) {
        upcomingFix += r.amountCents;
      }
    }
    final available = incomeMonth - expenseMonth - upcomingFix;
    final monthlyFixTotal = fixedExpenses.fold<int>(
      0,
      (s, r) => s + _monthlyEquivalent(r),
    );

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
    final deltaText = projDeltaPct == null
        ? null
        : '${projDeltaPct >= 0 ? '+' : ''}${projDeltaPct.round()}';

    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    // Saldo-artige Werte nur negativ in Ausgabenfarbe (wie Konten/Statistik).
    Color? signal(int cents) => cents < 0 ? colors.expense : null;

    Widget line(String label, int cents) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Bento.sub(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          MoneyText(cents, style: theme.textTheme.bodyMedium),
        ],
      ),
    );

    Widget bigAmount(int cents) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: MoneyText(
        cents,
        style: Bento.number(context, size: 32).copyWith(color: signal(cents)),
      ),
    );

    final availableTile = BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.availableUntilMonthEnd, style: Bento.label(context)),
          const SizedBox(height: 2),
          bigAmount(available),
          const SizedBox(height: 6),
          line(l.incomeMonthLabel, incomeMonth),
          line(l.minusExpensesSoFar, -expenseMonth),
          line(l.minusOpenFixed, -upcomingFix),
        ],
      ),
    );

    final projectionTile = BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.projectionMonthEnd,
                  style: Bento.label(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (deltaText != null)
                BentoChip(
                  icon: projDeltaPct! >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  child: Text(l.vsPrevMonthPct(deltaText)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          bigAmount(projectedNet),
          Text(l.expectedBalance, style: Bento.sub(context)),
          const SizedBox(height: 6),
          line(l.expectedExpenses, projectedExpense),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.atCurrentPace(daysElapsed, daysInMonth),
              style: Bento.sub(context),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.morePlanning)),
      body: ListView(
        padding: BentoListView.paddingOf(context),
        children: [
          BentoGrid(
            cells: [
              BentoCell(span: 2, child: availableTile),
              BentoCell(span: 2, child: projectionTile),
            ],
          ),
          const SizedBox(height: Bento.gap * 2),
          BentoSectionHeader(
            label: l.fixedCostsMonthly,
            trailing: MoneyText(monthlyFixTotal),
          ),
          if (fixedExpenses.isEmpty)
            BentoTile(child: Text(l.noFixedCosts, style: Bento.sub(context)))
          else
            BentoList(
              children: [
                for (final r in fixedExpenses)
                  BentoRow(
                    leading: const BentoGlyph(
                      size: 38,
                      child: Icon(Icons.repeat),
                    ),
                    title: Text(
                      r.title.isEmpty ? l.standingOrderNoun : r.title,
                    ),
                    subtitle: Text(
                      '${l.nextDuePrefix(df.format(r.nextDue))} · '
                      '${l.everyInterval(r.intervalCount, r.intervalUnit)}',
                    ),
                    subtitleMaxLines: 2,
                    trailing: MoneyText(r.amountCents),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
