import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/app_transaction.dart';
import '../../shared/mini_line_chart.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../transactions/person_filter_button.dart';
import 'period_filter.dart';
import 'statistics_providers.dart';

/// Farbpalette für die Kategorie-Diagramme.
const _palette = <Color>[
  Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800), Color(0xFF9C27B0),
  Color(0xFFF44336), Color(0xFF00BCD4), Color(0xFF8BC34A), Color(0xFFFFC107),
  Color(0xFF3F51B5), Color(0xFFE91E63), Color(0xFF009688), Color(0xFF795548),
  Color(0xFF607D8B), Color(0xFFCDDC39), Color(0xFFFF5722), Color(0xFF673AB7),
];

const _monthAbbr = [
  'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
  'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
];

/// Diagramm-Form für die Kategorie-Aufschlüsselung.
enum _ChartStyle { donut, pie, bars }

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
    final df = DateFormat('dd.MM.yyyy');
    final title = catId == null ? 'Ohne Kategorie' : (catNames[catId] ?? '—');

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
              subtitle: Text('${items.length} Buchungen'),
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
    final stats = ref.watch(statsProvider);
    final months = ref.watch(monthlyTotalsProvider);
    final netWorthHistory = ref.watch(netWorthHistoryProvider);
    final comparison = ref.watch(periodComparisonProvider);
    final topExpenses = ref.watch(topExpensesProvider);
    final catNames = ref.watch(categoryNamesProvider);
    String nameOf(String? id) =>
        id == null ? 'Ohne Kategorie' : (catNames[id] ?? 'Ohne Kategorie');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
        actions: const [PersonFilterButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<StatsPeriod>(
              segments: [
                for (final p in StatsPeriod.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(periodFilterProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Einnahmen',
                  cents: stats.incomeCents,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: 'Ausgaben',
                  cents: stats.expenseCents,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryCard(
            label: 'Saldo im Zeitraum',
            cents: stats.balanceCents,
            color: stats.balanceCents >= 0
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
          if (comparison.hasPrevious) ...[
            const SizedBox(height: 8),
            _ComparisonCard(comparison: comparison),
          ],
          const SizedBox(height: 16),
          _NetWorthTrendCard(history: netWorthHistory),
          const SizedBox(height: 12),
          _MonthlyTrendCard(months: months),
          const SizedBox(height: 12),
          _CategorySection(
            title: 'Ausgaben nach Kategorie',
            data: stats.expenseByCategory,
            nameOf: nameOf,
            onTapEntry: (catId) => _showDrilldown(context, ref, catId, true),
          ),
          const SizedBox(height: 12),
          _CategorySection(
            title: 'Einnahmen nach Kategorie',
            data: stats.incomeByCategory,
            nameOf: nameOf,
            onTapEntry: (catId) => _showDrilldown(context, ref, catId, false),
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
                  title: const Text('Gesamtvermögen'),
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
                  title: const Text('Schulden gesamt'),
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
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Keine Buchungen in diesem Zeitraum.')),
            ),
        ],
      ),
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
                  child: Text('Vermögensverlauf (12 Monate)',
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Noch zu wenige Daten.'),
              )
            else
              MiniLineChart(
                values: [for (final h in history) h.cents],
                color: Theme.of(context).colorScheme.primary,
                labels: [for (final h in history) _monthAbbr[h.month.month - 1]],
              ),
          ],
        ),
      ),
    );
  }
}

/// Monatstrend: gruppierte Balken (Einnahmen vs. Ausgaben) der letzten 12 Monate.
class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({required this.months});

  final List<MonthTotals> months;

  @override
  Widget build(BuildContext context) {
    final hasData =
        months.any((m) => m.incomeCents > 0 || m.expenseCents > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Monatstrend (letzte 12 Monate)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (!hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Noch keine Daten.'),
              )
            else ...[
              SizedBox(
                height: 180,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _TrendPainter(
                    months: months,
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
                  _LegendDot(color: Colors.green.shade600, label: 'Einnahmen'),
                  const SizedBox(width: 16),
                  _LegendDot(color: Colors.red.shade600, label: 'Ausgaben'),
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
    required this.incomeColor,
    required this.expenseColor,
    required this.axisColor,
    required this.labelColor,
  });

  final List<MonthTotals> months;
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
          text: _monthAbbr[months[i].month.month - 1],
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
                    segments: const [
                      ButtonSegment(
                          value: _ChartStyle.donut,
                          icon: Icon(Icons.donut_large, size: 18),
                          tooltip: 'Donut'),
                      ButtonSegment(
                          value: _ChartStyle.pie,
                          icon: Icon(Icons.pie_chart, size: 18),
                          tooltip: 'Kreis'),
                      ButtonSegment(
                          value: _ChartStyle.bars,
                          icon: Icon(Icons.bar_chart, size: 18),
                          tooltip: 'Balken'),
                    ],
                    selected: {_style},
                    onSelectionChanged: (s) =>
                        setState(() => _style = s.first),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Keine Daten.'),
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
                              Text('Gesamt',
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
  const _ComparisonCard({required this.comparison});

  final PeriodComparison comparison;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, double? pct, {required bool expense}) {
      final up = (pct ?? 0) > 0;
      // Ausgaben hoch = schlecht (rot); Einnahmen hoch = gut (grün).
      final good = expense ? !up : up;
      final color = pct == null || pct == 0
          ? null
          : (good ? Colors.green.shade700 : Colors.red.shade700);
      final txt = pct == null
          ? 'kein Vorwert'
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
            Text('Vergleich zum ${comparison.prevLabel}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            row('Ausgaben', comparison.expenseDeltaPct, expense: true),
            row('Einnahmen', comparison.incomeDeltaPct, expense: false),
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
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Größte Ausgaben',
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
                        ? 'Ausgabe'
                        : (catNames[t.categoryId] ?? 'Ausgabe'))
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
