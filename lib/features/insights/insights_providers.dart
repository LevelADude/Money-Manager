import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/models/savings_goal.dart';
import '../../shared/money.dart';
import '../budgets/budget_providers.dart';
import '../categories/category_providers.dart';
import '../currency/currency_providers.dart';
import '../recurring/recurring_providers.dart';
import '../savings/savings_providers.dart';
import '../settings/settings_providers.dart';
import '../statistics/statistics_providers.dart';
import '../transactions/person_filter.dart';
import '../transactions/transaction_providers.dart';

enum InsightSeverity { info, positive, warning }

/// Gruppierung der Karten im Insights-Bereich.
enum InsightSection { warning, overview, hint }

/// Betrachtungszeitraum für die Insights.
enum InsightScope { month, year }

/// Vom Nutzer gewählter Zeitraum (Monat/Jahr) für den Insights-Bereich.
class InsightScopeNotifier extends Notifier<InsightScope> {
  @override
  InsightScope build() => InsightScope.month;

  void set(InsightScope s) => state = s;
}

final insightScopeProvider =
    NotifierProvider<InsightScopeNotifier, InsightScope>(
        InsightScopeNotifier.new);

/// Eine lokal berechnete Auswertungs-Karte. Enthält KEINE Rohdaten, die das
/// Gerät verlassen. [route] (optional) macht die Karte antippbar und führt zur
/// passenden Ansicht.
class Insight {
  const Insight({
    required this.icon,
    required this.title,
    required this.detail,
    this.severity = InsightSeverity.info,
    this.route,
    this.section,
    this.sparkline,
    this.sparkLabels,
  });

  final IconData icon;
  final String title;
  final String detail;
  final InsightSeverity severity;
  final String? route;

  /// Abschnitt der Karte. Wenn null, wird er aus [severity] abgeleitet.
  final InsightSection? section;

  /// Optionale Mini-Verlaufslinie unter der Karte (z. B. Monatsverlauf).
  final List<int>? sparkline;
  final List<String>? sparkLabels;

  InsightSection get effectiveSection =>
      section ??
      switch (severity) {
        InsightSeverity.warning => InsightSection.warning,
        InsightSeverity.positive => InsightSection.overview,
        InsightSeverity.info => InsightSection.hint,
      };
}

/// Regelbasierte „KI"-Insights – komplett lokal, kostenlos, ohne Netz/LLM.
final localInsightsProvider = Provider<List<Insight>>((ref) {
  final scope = ref.watch(insightScopeProvider);
  final isYear = scope == InsightScope.year;

  final txs = ref.watch(personFilteredTransactionsProvider);
  final months = ref.watch(monthlyTotalsProvider);
  final netWorth = ref.watch(netWorthHistoryProvider);
  final convert = ref.watch(converterProvider);
  final curOf = ref.watch(accountCurrencyProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final cats = ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
  final catName = {for (final c in cats) c.id: c.name};
  final budgets = ref.watch(budgetsByCategoryProvider);
  final spentByCat = ref.watch(monthlySpentByCategoryProvider);
  final rules = ref.watch(recurringRulesProvider).asData?.value ??
      const <RecurringRule>[];
  final goals =
      ref.watch(savingsGoalsProvider).asData?.value ?? const <SavingsGoal>[];
  final splitsByTx = ref.watch(splitsByTransactionProvider);

  int amt(AppTransaction t) => convert(t.amountCents, curOf[t.accountId] ?? base);
  String nameOf(String? id) =>
      id == null ? 'Ohne Kategorie' : (catName[id] ?? 'Kategorie');

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

  // Betrachtungsfenster (Anfang bis einschließlich heute).
  final windowStart = isYear ? DateTime(now.year, 1, 1) : monthStart;
  final windowEnd =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final scopeWord = isYear ? 'dieses Jahr' : 'diesen Monat';
  final prevStart = isYear
      ? DateTime(now.year - 1, 1, 1)
      : DateTime(now.year, now.month - 1, 1);
  final prevEnd = windowStart;

  ({int income, int expense}) sums(DateTime start, DateTime end) {
    var inc = 0, exp = 0;
    for (final t in txs) {
      final d = t.occurredOn;
      if (d.isBefore(start) || !d.isBefore(end)) continue;
      if (t.type == TransactionType.income) {
        inc += amt(t);
      } else if (t.type == TransactionType.expense) {
        exp += amt(t);
      }
    }
    return (income: inc, expense: exp);
  }

  final w = sums(windowStart, windowEnd);
  final pv = sums(prevStart, prevEnd);

  // Ausgaben je Kategorie im Fenster + 3-Monats-Vorlauf (für Monatsvergleich).
  final winByCat = <String?, int>{};
  final prev3ByCat = <String?, int>{};
  final prev3Start = DateTime(now.year, now.month - 3, 1);
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    final d = t.occurredOn;
    if (!d.isBefore(windowStart) && d.isBefore(windowEnd)) {
      winByCat.update(t.categoryId, (v) => v + amt(t), ifAbsent: () => amt(t));
    }
    if (!d.isBefore(prev3Start) && d.isBefore(monthStart)) {
      prev3ByCat.update(t.categoryId, (v) => v + amt(t), ifAbsent: () => amt(t));
    }
  }
  final winExpense = w.expense;

  final out = <Insight>[];

  // ===== WARNUNGEN =========================================================

  // Budget-Status (nur im Monatszeitraum sinnvoll – Budgets sind monatlich).
  if (!isYear) {
    final budgetCards = <({double util, Insight insight})>[];
    budgets.forEach((catId, b) {
      if (b.amountCents <= 0) return;
      final spent = spentByCat[catId] ?? 0;
      final util = spent / b.amountCents;
      if (util < 0.9) return;
      final name = nameOf(catId);
      budgetCards.add((
        util: util,
        insight: Insight(
          icon: util >= 1.0 ? Icons.error_outline : Icons.warning_amber_outlined,
          title: util >= 1.0
              ? 'Budget „$name" überschritten'
              : 'Budget „$name" fast aufgebraucht',
          detail: '${formatCents(spent)} von ${formatCents(b.amountCents)} '
              '(${(util * 100).toStringAsFixed(0)} %) diesen Monat.',
          severity: InsightSeverity.warning,
          route: '/more/budgets',
        ),
      ));
    });
    budgetCards.sort((a, b) => b.util.compareTo(a.util));
    for (final c in budgetCards.take(2)) {
      out.add(c.insight);
    }
  }

  // Kategorie deutlich über dem 3-Monats-Schnitt (Monatszeitraum).
  if (!isYear) {
    String? topCat;
    double topPct = 0;
    int topCur = 0, topAvg = 0;
    winByCat.forEach((cat, cur) {
      final avg = (prev3ByCat[cat] ?? 0) / 3;
      if (avg < 1000) return;
      final pct = (cur - avg) / avg * 100;
      if (pct >= 20 && pct > topPct) {
        topPct = pct;
        topCat = cat;
        topCur = cur;
        topAvg = avg.round();
      }
    });
    if (topPct >= 20) {
      out.add(Insight(
        icon: Icons.show_chart,
        title: '${nameOf(topCat)} höher als sonst',
        detail: '${formatCents(topCur)} diesen Monat – +${topPct.toStringAsFixed(0)} % '
            'ggü. Ø der letzten 3 Monate (${formatCents(topAvg)}).',
        severity: InsightSeverity.warning,
        route: '/statistics',
      ));
    }
  }

  // Ausreißer: Buchung im Fenster > Mittel + 2·Std-Abw. ihrer Kategorie.
  final byCat = <String?, List<int>>{};
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    byCat.putIfAbsent(t.categoryId, () => []).add(amt(t));
  }
  final stats = <String?, ({double mean, double sd})>{};
  byCat.forEach((cat, list) {
    if (list.length < 5) return;
    final mean = list.reduce((a, b) => a + b) / list.length;
    final variance =
        list.map((v) => math.pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) /
            list.length;
    stats[cat] = (mean: mean, sd: math.sqrt(variance));
  });
  final outliers = <AppTransaction>[];
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    if (t.occurredOn.isBefore(windowStart)) continue;
    final s = stats[t.categoryId];
    if (s == null) continue;
    if (amt(t) > s.mean + 2 * s.sd && amt(t) >= 2000) outliers.add(t);
  }
  outliers.sort((a, b) => amt(b).compareTo(amt(a)));
  for (final t in outliers.take(2)) {
    final cat = nameOf(t.categoryId);
    out.add(Insight(
      icon: Icons.warning_amber_outlined,
      title: 'Ungewöhnlich hoch',
      detail: '${t.title.isEmpty ? cat : t.title}: ${formatCents(amt(t))} – '
          'deutlich über dem Schnitt der Kategorie „$cat".',
      severity: InsightSeverity.warning,
      route: '/transactions/${t.id}',
    ));
  }

  // ===== STATUS / ÜBERSICHT ================================================

  // Monatsverlauf (Netto) als Mini-Sparkline.
  if (months.length >= 3) {
    out.add(Insight(
      icon: Icons.ssid_chart,
      title: 'Monatsverlauf (Netto)',
      detail: 'Einnahmen minus Ausgaben der letzten ${months.length} Monate.',
      section: InsightSection.overview,
      route: '/statistics',
      sparkline: [for (final m in months) m.netCents],
      sparkLabels: [for (final m in months) _monthAbbr[m.month.month - 1]],
    ));
  }

  // Saldo des Zeitraums (Plus/Minus).
  final net = w.income - w.expense;
  out.add(Insight(
    icon: net >= 0 ? Icons.trending_up : Icons.trending_down,
    title: net >= 0 ? 'Im Plus ($scopeWord)' : 'Im Minus ($scopeWord)',
    detail: net >= 0
        ? 'Einnahmen liegen ${formatCents(net)} über den Ausgaben.'
        : 'Ausgaben liegen ${formatCents(-net)} über den Einnahmen.',
    severity: net >= 0 ? InsightSeverity.positive : InsightSeverity.warning,
    section: InsightSection.overview,
    route: '/statistics',
  ));

  // Sparquote (mit Trend ggü. Vorzeitraum).
  if (w.income > 0) {
    final rate = (w.income - w.expense) / w.income * 100;
    var detail = '$scopeWord bleiben ${rate.toStringAsFixed(0)} % deiner '
        'Einnahmen übrig.';
    if (pv.income > 0) {
      final prevRate = (pv.income - pv.expense) / pv.income * 100;
      final d = rate - prevRate;
      detail += ' (${d >= 0 ? '+' : ''}${d.toStringAsFixed(0)} %-Punkte ggü. '
          '${isYear ? 'Vorjahr' : 'Vormonat'})';
    }
    out.add(Insight(
      icon: Icons.savings_outlined,
      title: 'Sparquote',
      detail: detail,
      severity: rate >= 0 ? InsightSeverity.positive : InsightSeverity.warning,
      section: InsightSection.overview,
      route: '/statistics',
    ));
  }

  // Vermögenstrend (letzte 3 Monate – zeitraumunabhängig).
  if (netWorth.length >= 4) {
    final nowNw = netWorth.last.cents;
    final agoNw = netWorth[netWorth.length - 4].cents;
    final delta = nowNw - agoNw;
    if (delta.abs() >= 100) {
      out.add(Insight(
        icon: delta >= 0 ? Icons.trending_up : Icons.trending_down,
        title: 'Vermögenstrend (3 Monate)',
        detail: delta >= 0
            ? 'Dein Vermögen ist um ${formatCents(delta)} gewachsen '
                '(jetzt ${formatCents(nowNw)}).'
            : 'Dein Vermögen ist um ${formatCents(-delta)} gesunken '
                '(jetzt ${formatCents(nowNw)}).',
        severity:
            delta >= 0 ? InsightSeverity.positive : InsightSeverity.warning,
        section: InsightSection.overview,
        route: '/statistics',
      ));
    }
  }

  // Sparziel-Fortschritt (zeitraumunabhängig).
  final open = goals.where((g) => g.targetCents > 0 && !g.reached).toList()
    ..sort((a, b) => b.fraction.compareTo(a.fraction));
  final reached = goals.where((g) => g.reached).toList();
  if (open.isNotEmpty) {
    final g = open.first;
    out.add(Insight(
      icon: Icons.flag_outlined,
      title: 'Sparziel „${g.name}"',
      detail: '${(g.fraction * 100).toStringAsFixed(0)} % erreicht – noch '
          '${formatCents(g.remainingCents)} bis ${formatCents(g.targetCents)}.',
      section: InsightSection.overview,
      route: '/more/goals',
    ));
  } else if (reached.isNotEmpty) {
    out.add(Insight(
      icon: Icons.emoji_events_outlined,
      title: 'Sparziel erreicht 🎉',
      detail: '„${reached.first.name}" ist vollständig angespart.',
      severity: InsightSeverity.positive,
      section: InsightSection.overview,
      route: '/more/goals',
    ));
  }

  // ===== HINWEISE / INFOS ==================================================

  // Anstehende Daueraufträge (nächste 7 Tage – zeitraumunabhängig).
  final soon = now.add(const Duration(days: 7));
  var dueCount = 0;
  var dueExpense = 0;
  for (final r in rules) {
    if (!r.active) continue;
    if (!r.nextDue.isAfter(soon)) {
      dueCount++;
      if (r.type == TransactionType.expense) {
        dueExpense += convert(r.amountCents, curOf[r.accountId] ?? base);
      }
    }
  }
  if (dueCount > 0) {
    out.add(Insight(
      icon: Icons.event_repeat_outlined,
      title: '$dueCount Dauerauftrag${dueCount == 1 ? '' : 'e'} fällig (≤ 7 Tage)',
      detail: dueExpense > 0
          ? 'Davon ${formatCents(dueExpense)} Ausgaben. Sorge für Deckung.'
          : 'Demnächst fällig – im Blick behalten.',
      route: '/more/recurring',
    ));
  }

  // Hochrechnung (nur Monat).
  if (!isYear && winExpense > 0 && now.day >= 3 && now.day < daysInMonth) {
    final projected = (winExpense / now.day * daysInMonth).round();
    out.add(Insight(
      icon: Icons.query_stats,
      title: 'Hochrechnung',
      detail: 'Bei aktuellem Tempo ~${formatCents(projected)} Ausgaben bis '
          'Monatsende (bisher ${formatCents(winExpense)}).',
    ));
  }

  // Tagesdurchschnitt / Burn-Rate (nur Monat).
  if (!isYear && winExpense > 0 && now.day >= 2) {
    final perDay = (winExpense / now.day).round();
    out.add(Insight(
      icon: Icons.local_fire_department_outlined,
      title: 'Tagesdurchschnitt',
      detail: 'Du gibst diesen Monat im Schnitt ${formatCents(perDay)} pro Tag aus.',
    ));
  }

  // Größter Posten im Zeitraum (+ Anteil).
  if (winExpense > 0 && winByCat.isNotEmpty) {
    String? big;
    var bigV = -1;
    winByCat.forEach((cat, v) {
      if (v > bigV) {
        bigV = v;
        big = cat;
      }
    });
    final share = (bigV / winExpense * 100).round();
    out.add(Insight(
      icon: Icons.pie_chart_outline,
      title: 'Größter Posten: ${nameOf(big)}',
      detail: '${formatCents(bigV)} $scopeWord – $share % deiner Ausgaben.',
      route: '/statistics',
    ));
  }

  // Größte Einzel-Ausgabe im Zeitraum.
  AppTransaction? maxTx;
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    if (t.occurredOn.isBefore(windowStart) || !t.occurredOn.isBefore(windowEnd)) {
      continue;
    }
    if (maxTx == null || amt(t) > amt(maxTx)) maxTx = t;
  }
  if (maxTx != null) {
    final label = maxTx.title.isNotEmpty ? maxTx.title : nameOf(maxTx.categoryId);
    out.add(Insight(
      icon: Icons.payments_outlined,
      title: 'Größte Ausgabe ($scopeWord)',
      detail: '$label: ${formatCents(amt(maxTx))}.',
      route: '/transactions/${maxTx.id}',
    ));
  }

  // Ausgabenfreie Tage (nur Monat).
  if (!isYear && now.day >= 5) {
    final spendDays = <int>{};
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (t.occurredOn.isBefore(monthStart) || t.occurredOn.isAfter(now)) {
        continue;
      }
      spendDays.add(t.occurredOn.day);
    }
    final noSpend = now.day - spendDays.length;
    if (noSpend > 0) {
      out.add(Insight(
        icon: Icons.spa_outlined,
        title: '$noSpend ausgabenfreie Tage',
        detail: 'An $noSpend von ${now.day} Tagen diesen Monat hast du nichts '
            'ausgegeben.',
        severity: InsightSeverity.positive,
      ));
    }
  }

  // Mögliche Abos (zeitraumunabhängig).
  final groups = <String, List<AppTransaction>>{};
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    final title = t.title.trim().toLowerCase();
    if (title.isEmpty) continue;
    groups.putIfAbsent('$title|${t.amountCents}', () => []).add(t);
  }
  var subsShown = 0;
  for (final list in groups.values) {
    if (subsShown >= 2) break;
    if (list.length < 3) continue;
    final monthsSeen =
        list.map((t) => '${t.occurredOn.year}-${t.occurredOn.month}').toSet();
    if (monthsSeen.length < 3) continue;
    final t0 = list.first;
    out.add(Insight(
      icon: Icons.autorenew,
      title: 'Mögliches Abo',
      detail: '„${t0.title}" ${formatCents(t0.amountCents)} – ${list.length}× '
          'erkannt, wirkt regelmäßig.',
      route: '/more/subscriptions',
    ));
    subsShown++;
  }

  // Unkategorisierte Ausgaben im Zeitraum (Nudge).
  var uncategorized = 0;
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    if (t.occurredOn.isBefore(windowStart) || !t.occurredOn.isBefore(windowEnd)) {
      continue;
    }
    if (t.categoryId != null) continue;
    final splits = splitsByTx[t.id];
    if (splits != null && splits.isNotEmpty) continue;
    uncategorized++;
  }
  if (uncategorized >= 3) {
    out.add(Insight(
      icon: Icons.label_off_outlined,
      title: '$uncategorized Buchungen ohne Kategorie',
      detail: 'Kategorisieren verbessert die Auswertungen und Budgets.',
      route: '/transactions',
    ));
  }

  return out;
});

const _monthAbbr = [
  'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
  'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
];
