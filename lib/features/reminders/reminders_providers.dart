import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_transaction.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/models/savings_goal.dart';
import '../../shared/money.dart';
import '../budgets/budget_providers.dart';
import '../categories/category_providers.dart';
import '../recurring/recurring_providers.dart';
import '../savings/savings_providers.dart';
import '../transactions/transaction_providers.dart';

enum ReminderLevel { info, warning, alert }

class Reminder {
  const Reminder({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.level,
    this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ReminderLevel level;
  final String? route;
}

/// Sammelt offene Hinweise: fällige Daueraufträge, Budget-Warnungen,
/// nahe Sparziel-Termine.
final remindersProvider = Provider<List<Reminder>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final out = <Reminder>[];

  // Fällige / bald fällige Daueraufträge.
  final rules =
      ref.watch(recurringRulesProvider).asData?.value ??
      const <RecurringRule>[];
  for (final r in rules.where((r) => r.active)) {
    final due = DateTime(r.nextDue.year, r.nextDue.month, r.nextDue.day);
    final diff = due.difference(today).inDays;
    if (diff <= 3) {
      out.add(
        Reminder(
          icon: Icons.repeat,
          title: r.title.isEmpty ? 'Dauerauftrag' : r.title,
          subtitle: diff < 0
              ? 'überfällig seit ${-diff} Tag(en)'
              : diff == 0
              ? 'heute fällig'
              : 'fällig in $diff Tag(en)',
          level: diff < 0 ? ReminderLevel.alert : ReminderLevel.info,
          route: '/more/recurring',
        ),
      );
    }
  }

  // Budget-Warnungen (>= 90 %).
  final budgets = ref.watch(budgetsByCategoryProvider);
  final spent = ref.watch(monthlySpentByCategoryProvider);
  final catNames = ref.watch(categoryNamesProvider);
  budgets.forEach((catId, b) {
    if (b.amountCents <= 0) return;
    final s = spent[catId] ?? 0;
    final pct = s / b.amountCents;
    if (pct >= 0.9) {
      out.add(
        Reminder(
          icon: Icons.savings_outlined,
          title: 'Budget: ${catNames[catId] ?? 'Kategorie'}',
          subtitle: s > b.amountCents
              ? 'überschritten (${formatCents(s)} / ${formatCents(b.amountCents)})'
              : 'fast aufgebraucht (${(pct * 100).round()} %)',
          level: s > b.amountCents
              ? ReminderLevel.alert
              : ReminderLevel.warning,
          route: '/more/budgets',
        ),
      );
    }
  });

  // Sparziele mit nahem Termin.
  final goals =
      ref.watch(savingsGoalsProvider).asData?.value ?? const <SavingsGoal>[];
  for (final g in goals) {
    if (g.reached || g.targetDate == null || g.targetCents <= 0) continue;
    final td = DateTime(
      g.targetDate!.year,
      g.targetDate!.month,
      g.targetDate!.day,
    );
    final daysLeft = td.difference(today).inDays;
    if (daysLeft <= 14) {
      out.add(
        Reminder(
          icon: Icons.flag_outlined,
          title: 'Sparziel: ${g.name}',
          subtitle: daysLeft < 0
              ? 'Zieltermin überschritten · noch ${formatCents(g.remainingCents)}'
              : 'noch $daysLeft Tag(e) · ${formatCents(g.remainingCents)} fehlen',
          level: daysLeft < 0 ? ReminderLevel.alert : ReminderLevel.warning,
          route: '/more/goals',
        ),
      );
    }
  }

  // Sortierung: alert > warning > info.
  out.sort((a, b) => b.level.index.compareTo(a.level.index));
  return out;
});

/// Erfassungs-Streak: aufeinanderfolgende Tage mit mindestens einer Buchung.
final streakProvider = Provider<({int days, bool bookedToday})>((ref) {
  final txs =
      ref.watch(allTransactionsProvider).asData?.value ??
      const <AppTransaction>[];
  final daySet = <DateTime>{
    for (final t in txs)
      DateTime(t.occurredOn.year, t.occurredOn.month, t.occurredOn.day),
  };
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final bookedToday = daySet.contains(today);
  var cursor = bookedToday ? today : today.subtract(const Duration(days: 1));
  var streak = 0;
  while (daySet.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return (days: streak, bookedToday: bookedToday);
});
