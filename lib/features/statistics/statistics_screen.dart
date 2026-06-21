import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/data_refresh.dart';
import '../../shared/mini_line_chart.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../profile/profile_switcher.dart';
import '../transactions/person_filter.dart';
import 'period_filter.dart';
import 'statistics_providers.dart';

/// Farbpalette für die Kategorie-Diagramme.
const _palette = <Color>[
  Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800), Color(0xFF9C27B0),
  Color(0xFFF44336), Color(0xFF00BCD4), Color(0xFF8BC34A), Color(0xFFFFC107),
  Color(0xFF3F51B5), Color(0xFFE91E63), Color(0xFF009688), Color(0xFF795548),
  Color(0xFF607D8B), Color(0xFFCDDC39), Color(0xFFFF5722), Color(0xFF673AB7),
];

/// Diagramm-Form für die Kategorie-Aufschlüsselung.
enum _ChartStyle { donut, pie, bars }

String _statsPeriodLabel(AppLocalizations l, StatsPeriod p) => switch (p) {
      StatsPeriod.thisDay => l.periodDay,
      StatsPeriod.thisWeek => l.periodWeek,
      StatsPeriod.thisMonth => l.periodMonth,
      StatsPeriod.thisYear => l.periodYear,
      StatsPeriod.all => l.allTime,
    };

String _prevPeriodLabel(AppLocalizations l, StatsPeriod p) => switch (p) {
      StatsPeriod.thisDay => l.prevDay,
      StatsPeriod.thisWeek => l.prevWeek,
      StatsPeriod.thisMonth => l.prevMonth,
      StatsPeriod.thisYear => l.prevYear,
      StatsPeriod.all => '',
    };

/// Lokalisierte Bezeichnung des Zeitfensters (Ersatz für labelFor).
String _statsRangeLabel(AppLocalizations l, StatsPeriod p, DateTime a) {
  String d2(int n) => n.toString().padLeft(2, '0');
  switch (p) {
    case StatsPeriod.thisDay:
      return '${d2(a.day)}.${d2(a.month)}.${a.year}';
    case StatsPeriod.thisWeek:
      final start = a.subtract(Duration(days: a.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return '${d2(start.day)}.${d2(start.month)}. – '
          '${d2(end.day)}.${d2(end.month)}.${end.year}';
    case StatsPeriod.thisMonth:
      return '${l.monthName(a.month)} ${a.year}';
    case StatsPeriod.thisYear:
      return '${a.year}';
    case StatsPeriod.all:
      return l.allTime;
  }
}

/// Statistik-Fenster: Zeitraum-Summen, Monatstrend, Kategorie-Diagramme
/// (umschaltbar Donut/Kreis/Balken, mit Prozenten), Vermögen/Schulden.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  void _showDrilldown(
      BuildContext context, WidgetRef ref, String? catId, bool expense) {
    final items =
        categoryDrilldown(ref, categoryId: catId, expense: expense);
    final catNames = ref.read(categoryNamesProvider);
    final accounts = ref.read(accountsProvider).asData?.value ?? const [];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');
    final title = catId == null ? l.noCategory : (catNames[catId] ?? '—');

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          children: [
            ListTile(
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(l.txCount(items.length)),
            ),
            const Divider(height: 1),
            for (final t in items)
              ListTile(
                title: Text(t.title.isEmpty ? title : t.title),
                subtitle: Text(
                    '${df.format(t.occurredOn)} · ${accountNames[t.accountId] ?? ''}'),
                trailing: MoneyText(t.amountCents,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/transactions/${t.id}');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodFilterProvider);
    final anchor = ref.watch(statsAnchorProvider);
    final stats = ref.watch(statsProvider);
    final months = ref.watch(monthlyTotalsProvider);
    final netWorthHistory = ref.watch(netWorthHistoryProvider);
    final comparison = ref.watch(periodComparisonProvider);
    final topExpenses = ref.watch(topExpensesProvider);
    final catNames = ref.watch(categoryNamesProvider);

    // Tägliche Ausgaben des angezeigten Jahres für die Heatmap (Monat + Jahr).
    final pfTxs = ref.watch(personFilteredTransactionsProvider);
    final hmNow = anchor;
    final dailyByDate = <DateTime, int>{};
    for (final t in pfTxs) {
      if (t.type != TransactionType.expense) continue;
      if (t.occurredOn.year != hmNow.year) continue;
      final d =
          DateTime(t.occurredOn.year, t.occurredOn.month, t.occurredOn.day);
      dailyByDate.update(d, (v) => v + t.amountCents,
          ifAbsent: () => t.amountCents);
    }
    final l = AppLocalizations.of(context);
    String nameOf(String? id) =>
        id == null ? l.noCategory : (catNames[id] ?? l.noCategory);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navStatistics),
        actions: [
          const ProfileSwitcher(),
          IconButton(
            tooltip: l.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => refreshAllData(ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<StatsPeriod>(
              segments: [
                for (final p in StatsPeriod.values)
                  ButtonSegment(value: p, label: Text(_statsPeriodLabel(l, p))),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(periodFilterProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: 8),
          _PeriodNavBar(period: period, anchor: anchor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: l.income,
                  cents: stats.incomeCents,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: l.expenses,
                  cents: stats.expenseCents,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryCard(
            label: l.balanceInPeriod,
            cents: stats.balanceCents,
            color: stats.balanceCents >= 0
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
          if (comparison.hasPrevious) ...[
            const SizedBox(height: 8),
            _ComparisonCard(
                comparison: comparison,
                prevLabel: _prevPeriodLabel(l, period)),
          ],
          const SizedBox(height: 16),
          _NetWorthTrendCard(history: netWorthHistory),
          const SizedBox(height: 12),
          _MonthlyTrendCard(months: months),
          const SizedBox(height: 12),
          _HeatmapCard(
            year: hmNow.year,
            month: hmNow.month,
            dailyByDate: dailyByDate,
          ),
          const SizedBox(height: 12),
          _CategorySection(
            title: l.expensesByCategory,
            data: stats.expenseByCategory,
            nameOf: nameOf,
            onTapEntry: (catId) => _showDrilldown(context, ref, catId, true),
          ),
          const SizedBox(height: 12),
          _CategorySection(
            title: l.incomeByCategory,
            data: stats.incomeByCategory,
            nameOf: nameOf,
            onTapEntry: (catId) => _showDrilldown(context, ref, catId, false),
          ),
          const SizedBox(height: 12),
          _SankeyCard(
            income: stats.incomeByCategory,
            expense: stats.expenseByCategory,
            nameOf: nameOf,
          ),
          const SizedBox(height: 12),
          if (topExpenses.isNotEmpty) ...[
            _TopExpensesCard(items: topExpenses),
            const SizedBox(height: 12),
          ],
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_outlined),
                  title: Text(l.netWorth),
                  trailing: MoneyText(
                    stats.netWorthCents,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: stats.netWorthCents >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.trending_down),
                  title: Text(l.totalDebt),
                  trailing: MoneyText(
                    stats.debtCents,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: stats.debtCents > 0 ? Colors.red.shade700 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (stats.txCount == 0)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l.noTransactionsPeriod)),
            ),
        ],
      ),
    );
  }
}

/// Zeigt den aktuell dargestellten Zeitraum an und erlaubt das Blättern
/// (vorige/nächste Periode). Bei „Gesamt" gibt es nichts zu blättern.
class _PeriodNavBar extends ConsumerWidget {
  const _PeriodNavBar({required this.period, required this.anchor});

  final StatsPeriod period;
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final label = _statsRangeLabel(l, period, anchor);
    if (period == StatsPeriod.all) {
      return Center(
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
    }

    // Ist der angezeigte Zeitraum der aktuelle? Dann kein „Vorblättern" in die
    // Zukunft und kein „Heute"-Knopf.
    final now = DateTime.now();
    final range = rangeFor(period, anchor, previous: false);
    final isCurrent = range == null ||
        (!now.isBefore(range.start) && now.isBefore(range.end));
    final notifier = ref.read(statsAnchorProvider.notifier);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: l.back,
          onPressed: () => notifier.shift(period, -1),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              if (!isCurrent)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: notifier.reset,
                  child: Text(l.today),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: l.forward,
          // Nicht in die Zukunft blättern.
          onPressed: isCurrent ? null : () => notifier.shift(period, 1),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.cents,
    required this.color,
  });

  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            MoneyText(
              cents,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vermögensverlauf: Liniendiagramm des Gesamtvermögens über 12 Monate.
class _NetWorthTrendCard extends StatelessWidget {
  const _NetWorthTrendCard({required this.history});

  final List<({DateTime month, int cents})> history;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasData = history.length >= 2;
    final current = history.isEmpty ? 0 : history.last.cents;
    final first = history.isEmpty ? 0 : history.first.cents;
    final delta = current - first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.netWorthTrend12,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                MoneyText(current,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: current >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700)),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(delta >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: delta >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700),
                  const SizedBox(width: 4),
                  MoneyText(delta,
                      prefix: delta >= 0 ? '+' : '',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l.tooFewData),
              )
            else
              MiniLineChart(
                values: [for (final h in history) h.cents],
                color: Theme.of(context).colorScheme.primary,
                labels: [
                  for (final h in history) l.monthAbbr[h.month.month - 1]
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Geldfluss (vereinfachtes Sankey): Einnahmen-Kategorien → Pool → Ausgaben.
class _SankeyCard extends StatelessWidget {
  const _SankeyCard({
    required this.income,
    required this.expense,
    required this.nameOf,
  });

  final Map<String?, int> income;
  final Map<String?, int> expense;
  final String Function(String?) nameOf;

  // Top-N Kategorien + Rest als „Sonstige".
  List<({String label, int value, Color color})> _entries(
      Map<String?, int> data, int offset, String restLabel) {
    final list = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = list.take(6).toList();
    final restVal = list.skip(6).fold<int>(0, (s, e) => s + e.value);
    final result = <({String label, int value, Color color})>[];
    for (var i = 0; i < top.length; i++) {
      result.add((
        label: nameOf(top[i].key),
        value: top[i].value,
        color: _palette[(offset + i) % _palette.length],
      ));
    }
    if (restVal > 0) {
      result.add((
        label: restLabel,
        value: restVal,
        color: _palette[(offset + top.length) % _palette.length],
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final left = _entries(income, 0, l.other);
    final right = _entries(expense, 8, l.other);
    if (left.isEmpty && right.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.moneyFlow,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: Size.infinite,
                painter: _SankeyPainter(
                  left: [for (final e in left) (value: e.value, color: e.color)],
                  right: [
                    for (final e in right) (value: e.value, color: e.color)
                  ],
                  poolColor: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _legend(context, l.income, left)),
                Expanded(child: _legend(context, l.expenses, right)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(BuildContext context,
      String title, List<({String label, int value, Color color})> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: e.color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(e.label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SankeyPainter extends CustomPainter {
  _SankeyPainter({
    required this.left,
    required this.right,
    required this.poolColor,
  });

  final List<({int value, Color color})> left;
  final List<({int value, Color color})> right;
  final Color poolColor;

  @override
  void paint(Canvas canvas, Size size) {
    final sumLeft = left.fold<int>(0, (s, e) => s + e.value);
    final sumRight = right.fold<int>(0, (s, e) => s + e.value);
    final maxTotal = math.max(sumLeft, sumRight);
    if (maxTotal <= 0) return;

    const nodeW = 12.0;
    final h = size.height;
    final leftX = 0.0;
    final centerX = size.width / 2 - nodeW / 2;
    final rightX = size.width - nodeW;

    void band(double x1, double ya1, double yb1, double x2, double ya2,
        double yb2, Color c) {
      final mid = (x1 + x2) / 2;
      final p = Path()
        ..moveTo(x1, ya1)
        ..cubicTo(mid, ya1, mid, ya2, x2, ya2)
        ..lineTo(x2, yb2)
        ..cubicTo(mid, yb2, mid, yb1, x1, yb1)
        ..close();
      canvas.drawPath(p, Paint()..color = c.withValues(alpha: 0.35));
    }

    // Einnahmen links → Pool.
    var ly = 0.0;
    for (final e in left) {
      final segH = e.value / maxTotal * h;
      canvas.drawRect(
          Rect.fromLTWH(leftX, ly, nodeW, segH), Paint()..color = e.color);
      band(leftX + nodeW, ly, ly + segH, centerX, ly, ly + segH, e.color);
      ly += segH;
    }

    // Pool (Mitte).
    final poolH = math.max(sumLeft, sumRight) / maxTotal * h;
    canvas.drawRect(Rect.fromLTWH(centerX, 0, nodeW, poolH),
        Paint()..color = poolColor);

    // Pool → Ausgaben rechts.
    var ry = 0.0;
    for (final e in right) {
      final segH = e.value / maxTotal * h;
      canvas.drawRect(
          Rect.fromLTWH(rightX, ry, nodeW, segH), Paint()..color = e.color);
      band(centerX + nodeW, ry, ry + segH, rightX, ry, ry + segH, e.color);
      ry += segH;
    }
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter old) => true;
}

/// Anzeige-Modus der Ausgaben-Heatmap.
enum _HeatMode { month, year }

/// Heatmap der täglichen Ausgaben – umschaltbar zwischen Monat (Kalenderraster)
/// und Jahr (GitHub-artiges Wochen-Raster, horizontal scrollbar).
class _HeatmapCard extends StatefulWidget {
  const _HeatmapCard({
    required this.year,
    required this.month,
    required this.dailyByDate,
  });

  final int year;
  final int month;
  final Map<DateTime, int> dailyByDate;

  @override
  State<_HeatmapCard> createState() => _HeatmapCardState();
}

class _HeatmapCardState extends State<_HeatmapCard> {
  _HeatMode _mode = _HeatMode.month;

  Color _cellColor(int cents, int maxVal) {
    final base = Theme.of(context).colorScheme.primary;
    if (cents <= 0) return base.withValues(alpha: 0.05);
    final intensity = (0.18 + 0.82 * (cents / (maxVal == 0 ? 1 : maxVal)))
        .clamp(0.0, 1.0);
    return base.withValues(alpha: intensity);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _mode == _HeatMode.month ? l.heatmapMonth : l.heatmapYear,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                SegmentedButton<_HeatMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: [
                    ButtonSegment(
                        value: _HeatMode.month, label: Text(l.periodMonth)),
                    ButtonSegment(
                        value: _HeatMode.year, label: Text(l.periodYear)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_mode == _HeatMode.month) _buildMonth() else _buildYear(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonth() {
    final year = widget.year;
    final month = widget.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mo
    int valOf(int d) => widget.dailyByDate[DateTime(year, month, d)] ?? 0;
    var maxDay = 1;
    for (var d = 1; d <= daysInMonth; d++) {
      final v = valOf(d);
      if (v > maxDay) maxDay = v;
    }

    final cells = <Widget>[];
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final e = valOf(d);
      final intensity = e == 0 ? 0.0 : (0.18 + 0.82 * (e / maxDay));
      cells.add(Tooltip(
        message: e == 0 ? '$d.' : '$d. · ${formatCents(e)}',
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _cellColor(e, maxDay),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text('$d',
              style: TextStyle(
                fontSize: 10,
                color: intensity > 0.55 ? Colors.white : null,
              )),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final w in AppLocalizations.of(context).weekdayAbbr)
              Expanded(
                child: Center(
                  child:
                      Text(w, style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
      ],
    );
  }

  Widget _buildYear() {
    final year = widget.year;
    final firstDay = DateTime(year, 1, 1);
    final lastDay = DateTime(year, 12, 31);
    final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    var maxVal = 1;
    widget.dailyByDate.forEach((_, v) {
      if (v > maxVal) maxVal = v;
    });

    // Montage aller Wochen (Spalten).
    final weeks = <DateTime>[];
    var w = firstMonday;
    while (!w.isAfter(lastDay)) {
      weeks.add(w);
      w = w.add(const Duration(days: 7));
    }

    const cell = 13.0;
    const slot = cell + 3; // Zelle + 2x1.5 Rand

    Widget dayCell(DateTime day) {
      final inYear = day.year == year;
      final e = inYear ? (widget.dailyByDate[day] ?? 0) : 0;
      return Container(
        width: cell,
        height: cell,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: inYear ? _cellColor(e, maxVal) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: inYear
            ? Tooltip(
                message: e == 0 ? _fmtDate(day) : '${_fmtDate(day)} · ${formatCents(e)}',
                child: const SizedBox.expand(),
              )
            : null,
      );
    }

    // Monatsbeschriftung über den Spalten (bei Monatswechsel).
    final monthLabels = <Widget>[];
    int? lastMonth;
    for (final wk in weeks) {
      final rep = wk.isBefore(firstDay) ? firstDay : wk;
      final show = rep.month != lastMonth;
      lastMonth = rep.month;
      monthLabels.add(SizedBox(
        width: slot,
        child: show
            ? Text(AppLocalizations.of(context).monthAbbr[rep.month - 1],
                style: Theme.of(context).textTheme.labelSmall)
            : const SizedBox.shrink(),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: monthLabels),
              const SizedBox(height: 2),
              Row(
                children: [
                  for (final wk in weeks)
                    Column(
                      children: [
                        for (var i = 0; i < 7; i++)
                          dayCell(wk.add(Duration(days: i))),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(AppLocalizations.of(context).less,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(width: 4),
            for (final a in const [0.05, 0.3, 0.55, 0.8, 1.0])
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: a),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 4),
            Text(AppLocalizations.of(context).more,
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

/// Monatstrend: gruppierte Balken (Einnahmen vs. Ausgaben) der letzten 12 Monate.
class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({required this.months});

  final List<MonthTotals> months;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasData =
        months.any((m) => m.incomeCents > 0 || m.expenseCents > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.monthlyTrend12,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l.noDataYet),
              )
            else ...[
              SizedBox(
                height: 180,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _TrendPainter(
                    months: months,
                    monthAbbr: l.monthAbbr,
                    incomeColor: Colors.green.shade600,
                    expenseColor: Colors.red.shade600,
                    axisColor: Theme.of(context).dividerColor,
                    labelColor: Theme.of(context).hintColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: Colors.green.shade600, label: l.income),
                  const SizedBox(width: 16),
                  _LegendDot(color: Colors.red.shade600, label: l.expenses),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.months,
    required this.monthAbbr,
    required this.incomeColor,
    required this.expenseColor,
    required this.axisColor,
    required this.labelColor,
  });

  final List<MonthTotals> months;
  final List<String> monthAbbr;
  final Color incomeColor;
  final Color expenseColor;
  final Color axisColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0;
    final chartH = size.height - labelH;
    final maxVal = months.fold<int>(
      1,
      (m, e) => math.max(m, math.max(e.incomeCents, e.expenseCents)),
    );

    // Baseline
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, chartH), Offset(size.width, chartH), axis);

    final slot = size.width / months.length;
    final barW = math.min(slot * 0.32, 14.0);
    final gap = barW * 0.18;

    for (var i = 0; i < months.length; i++) {
      final cx = slot * i + slot / 2;
      final incH = months[i].incomeCents / maxVal * (chartH - 4);
      final expH = months[i].expenseCents / maxVal * (chartH - 4);

      final incRect = Rect.fromLTWH(
          cx - barW - gap / 2, chartH - incH, barW, incH);
      final expRect = Rect.fromLTWH(cx + gap / 2, chartH - expH, barW, expH);
      final r = const Radius.circular(2);
      canvas.drawRRect(RRect.fromRectAndCorners(incRect, topLeft: r, topRight: r),
          Paint()..color = incomeColor);
      canvas.drawRRect(RRect.fromRectAndCorners(expRect, topLeft: r, topRight: r),
          Paint()..color = expenseColor);

      // Monatslabel
      final tp = TextPainter(
        text: TextSpan(
          text: monthAbbr[months[i].month.month - 1],
          style: TextStyle(color: labelColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartH + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}

/// Kategorie-Aufschlüsselung mit umschaltbarer Diagrammform (Donut/Kreis/Balken)
/// und Legende (Name · Prozent · Betrag).
class _CategorySection extends StatefulWidget {
  const _CategorySection({
    required this.title,
    required this.data,
    required this.nameOf,
    this.onTapEntry,
  });

  final String title;
  final Map<String?, int> data;
  final String Function(String?) nameOf;
  final void Function(String? categoryId)? onTapEntry;

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  _ChartStyle _style = _ChartStyle.donut;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entries = widget.data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (entries.isNotEmpty)
                  SegmentedButton<_ChartStyle>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: [
                      ButtonSegment(
                          value: _ChartStyle.donut,
                          icon: const Icon(Icons.donut_large, size: 18),
                          tooltip: l.chartDonut),
                      ButtonSegment(
                          value: _ChartStyle.pie,
                          icon: const Icon(Icons.pie_chart, size: 18),
                          tooltip: l.chartPie),
                      ButtonSegment(
                          value: _ChartStyle.bars,
                          icon: const Icon(Icons.bar_chart, size: 18),
                          tooltip: l.chartBars),
                    ],
                    selected: {_style},
                    onSelectionChanged: (s) =>
                        setState(() => _style = s.first),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l.noData),
              )
            else ...[
              if (_style != _ChartStyle.bars)
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(160, 160),
                          painter: _PiePainter(
                            values: [for (final e in entries) e.value],
                            colors: [
                              for (var i = 0; i < entries.length; i++)
                                _palette[i % _palette.length],
                            ],
                            donut: _style == _ChartStyle.donut,
                            strokeWidth: 24,
                          ),
                        ),
                        if (_style == _ChartStyle.donut)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l.total,
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              MoneyText(
                                total,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              if (_style != _ChartStyle.bars) const SizedBox(height: 12),
              for (var i = 0; i < entries.length; i++)
                _LegendRow(
                  color: _palette[i % _palette.length],
                  name: widget.nameOf(entries[i].key),
                  cents: entries[i].value,
                  percent: total == 0 ? 0 : entries[i].value / total * 100,
                  onTap: widget.onTapEntry == null
                      ? null
                      : () => widget.onTapEntry!(entries[i].key),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.name,
    required this.cents,
    required this.percent,
    this.onTap,
  });

  final Color color;
  final String name;
  final int cents;
  final double percent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pct = percent >= 10 || percent == 0
        ? '${percent.round()} %'
        : '${percent.toStringAsFixed(1)} %';
    return InkWell(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
              Text(pct,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor)),
              const SizedBox(width: 10),
              MoneyText(cents,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison, required this.prevLabel});

  final PeriodComparison comparison;
  final String prevLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget row(String label, double? pct, {required bool expense}) {
      final up = (pct ?? 0) > 0;
      // Ausgaben hoch = schlecht (rot); Einnahmen hoch = gut (grün).
      final good = expense ? !up : up;
      final color = pct == null || pct == 0
          ? null
          : (good ? Colors.green.shade700 : Colors.red.shade700);
      final txt = pct == null
          ? l.noPrevValue
          : '${up ? '+' : ''}${pct.round()} %';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            if (pct != null && pct != 0)
              Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16, color: color),
            const SizedBox(width: 4),
            Text(txt,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.comparisonTo(prevLabel),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            row(l.expenses, comparison.expenseDeltaPct, expense: true),
            row(l.income, comparison.incomeDeltaPct, expense: false),
          ],
        ),
      ),
    );
  }
}

class _TopExpensesCard extends ConsumerWidget {
  const _TopExpensesCard({required this.items});

  final List<AppTransaction> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const [];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);
    final l = AppLocalizations.of(context);
    final expenseWord = l.transactionType(TransactionType.expense);
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(l.topExpenses,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          for (final t in items)
            ListTile(
              dense: true,
              title: Text(
                t.title.isEmpty
                    ? (t.categoryId == null
                        ? expenseWord
                        : (catNames[t.categoryId] ?? expenseWord))
                    : t.title,
              ),
              subtitle: Text(accountNames[t.accountId] ?? ''),
              trailing: MoneyText(t.amountCents,
                  prefix: '-',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red.shade700)),
              onTap: () => context.go('/transactions/${t.id}'),
            ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.values,
    required this.colors,
    required this.donut,
    required this.strokeWidth,
  });

  final List<int> values;
  final List<Color> colors;
  final bool donut;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final total = values.fold<int>(0, (s, v) => s + v);
    if (total <= 0) return;

    if (donut) {
      final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
      final rect = Rect.fromCircle(center: center, radius: radius);
      var start = -math.pi / 2;
      for (var i = 0; i < values.length; i++) {
        final sweep = values[i] / total * 2 * math.pi;
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = colors[i % colors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.butt,
        );
        start += sweep;
      }
    } else {
      final radius = math.min(size.width, size.height) / 2;
      final rect = Rect.fromCircle(center: center, radius: radius);
      var start = -math.pi / 2;
      for (var i = 0; i < values.length; i++) {
        final sweep = values[i] / total * 2 * math.pi;
        canvas.drawArc(
          rect,
          start,
          sweep,
          true,
          Paint()
            ..color = colors[i % colors.length]
            ..style = PaintingStyle.fill,
        );
        start += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => true;
}
