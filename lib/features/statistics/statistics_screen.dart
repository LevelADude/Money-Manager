import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/money_text.dart';
import '../categories/category_providers.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodFilterProvider);
    final stats = ref.watch(statsProvider);
    final months = ref.watch(monthlyTotalsProvider);
    final catNames = ref.watch(categoryNamesProvider);
    String nameOf(String? id) =>
        id == null ? 'Ohne Kategorie' : (catNames[id] ?? 'Ohne Kategorie');

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
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
          const SizedBox(height: 16),
          _MonthlyTrendCard(months: months),
          const SizedBox(height: 12),
          _CategorySection(
            title: 'Ausgaben nach Kategorie',
            data: stats.expenseByCategory,
            nameOf: nameOf,
          ),
          const SizedBox(height: 12),
          _CategorySection(
            title: 'Einnahmen nach Kategorie',
            data: stats.incomeByCategory,
            nameOf: nameOf,
          ),
          const SizedBox(height: 12),
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
  });

  final String title;
  final Map<String?, int> data;
  final String Function(String?) nameOf;

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
  });

  final Color color;
  final String name;
  final int cents;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final pct = percent >= 10 || percent == 0
        ? '${percent.round()} %'
        : '${percent.toStringAsFixed(1)} %';
    return Padding(
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
