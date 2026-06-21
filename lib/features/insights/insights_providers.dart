import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../../shared/money.dart';
import '../categories/category_providers.dart';
import '../currency/currency_providers.dart';
import '../settings/settings_providers.dart';
import '../statistics/statistics_providers.dart';
import '../transactions/person_filter.dart';

enum InsightSeverity { info, positive, warning }

/// Eine lokal berechnete Auswertungs-Karte. Enthält KEINE Rohdaten, die das
/// Gerät verlassen – alles wird aus den bereits geladenen Buchungen abgeleitet.
class Insight {
  const Insight({
    required this.icon,
    required this.title,
    required this.detail,
    this.severity = InsightSeverity.info,
  });

  final IconData icon;
  final String title;
  final String detail;
  final InsightSeverity severity;
}

/// Regelbasierte „KI"-Insights – komplett lokal, kostenlos, ohne Netz/LLM.
final localInsightsProvider = Provider<List<Insight>>((ref) {
  final txs = ref.watch(personFilteredTransactionsProvider);
  final months = ref.watch(monthlyTotalsProvider);
  final convert = ref.watch(converterProvider);
  final curOf = ref.watch(accountCurrencyProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final cats = ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
  final catName = {for (final c in cats) c.id: c.name};

  int amt(AppTransaction t) => convert(t.amountCents, curOf[t.accountId] ?? base);
  String nameOf(String? id) =>
      id == null ? 'Ohne Kategorie' : (catName[id] ?? 'Kategorie');

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final out = <Insight>[];

  // --- 1) Sparquote (aktueller Monat, mit Trend) ---------------------------
  if (months.isNotEmpty && months.last.incomeCents > 0) {
    final cur = months.last;
    final rate = (cur.incomeCents - cur.expenseCents) / cur.incomeCents * 100;
    var detail = 'Diesen Monat bleiben ${rate.toStringAsFixed(0)} % deiner '
        'Einnahmen übrig.';
    if (months.length >= 2 && months[months.length - 2].incomeCents > 0) {
      final prev = months[months.length - 2];
      final prevRate =
          (prev.incomeCents - prev.expenseCents) / prev.incomeCents * 100;
      final d = rate - prevRate;
      detail += ' (${d >= 0 ? '+' : ''}${d.toStringAsFixed(0)} %-Punkte ggü. '
          'Vormonat)';
    }
    out.add(Insight(
      icon: Icons.savings_outlined,
      title: 'Sparquote',
      detail: detail,
      severity: rate >= 0 ? InsightSeverity.positive : InsightSeverity.warning,
    ));
  }

  // --- 2) Hochrechnung Ausgaben bis Monatsende -----------------------------
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  if (months.isNotEmpty && now.day >= 3 && now.day < daysInMonth) {
    final spent = months.last.expenseCents;
    if (spent > 0) {
      final projected = (spent / now.day * daysInMonth).round();
      out.add(Insight(
        icon: Icons.trending_up,
        title: 'Hochrechnung',
        detail: 'Bei aktuellem Tempo ~${formatCents(projected)} Ausgaben bis '
            'Monatsende (bisher ${formatCents(spent)}).',
      ));
    }
  }

  // --- 3) Kategorie deutlich über dem 3-Monats-Schnitt ---------------------
  final prev3Start = DateTime(now.year, now.month - 3, 1);
  final curByCat = <String?, int>{};
  final prevByCat = <String?, int>{};
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    final d = t.occurredOn;
    if (!d.isBefore(monthStart)) {
      curByCat.update(t.categoryId, (v) => v + amt(t), ifAbsent: () => amt(t));
    } else if (!d.isBefore(prev3Start)) {
      prevByCat.update(t.categoryId, (v) => v + amt(t), ifAbsent: () => amt(t));
    }
  }
  String? topCat;
  double topPct = 0;
  int topCur = 0, topAvg = 0;
  curByCat.forEach((cat, cur) {
    final avg = (prevByCat[cat] ?? 0) / 3;
    if (avg < 1000) return; // Mini-Kategorien (<10 €/Monat) ignorieren
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
    ));
  }

  // --- 4) Ausreißer (Buchung > Mittel + 2·Std-Abw. der Kategorie) ----------
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
    if (t.occurredOn.isBefore(monthStart)) continue;
    final s = stats[t.categoryId];
    if (s == null) continue;
    final v = amt(t);
    if (v > s.mean + 2 * s.sd && v >= 2000) outliers.add(t);
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
    ));
  }

  // --- 5) Mögliche Abos (gleicher Titel + Betrag, mehrere Monate) ----------
  final groups = <String, List<AppTransaction>>{};
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    final title = t.title.trim().toLowerCase();
    if (title.isEmpty) continue;
    groups.putIfAbsent('$title|${t.amountCents}', () => []).add(t);
  }
  var subsShown = 0;
  for (final list in groups.values) {
    if (subsShown >= 3) break;
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
    ));
    subsShown++;
  }

  // --- 6) Größte Einzel-Ausgabe diesen Monat -------------------------------
  AppTransaction? maxTx;
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    if (t.occurredOn.isBefore(monthStart)) continue;
    if (maxTx == null || amt(t) > amt(maxTx)) maxTx = t;
  }
  if (maxTx != null) {
    final label = maxTx.title.isNotEmpty ? maxTx.title : nameOf(maxTx.categoryId);
    out.add(Insight(
      icon: Icons.payments_outlined,
      title: 'Größte Ausgabe diesen Monat',
      detail: '$label: ${formatCents(amt(maxTx))}.',
    ));
  }

  return out;
});
