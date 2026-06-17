import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/money.dart';
import '../categories/category_providers.dart';
import 'period_filter.dart';
import 'statistics_providers.dart';

/// Statistik-Fenster: Zeitraum-Summen, Kategorie-Aufschlüsselung, Vermögen/Schulden.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodFilterProvider);
    final stats = ref.watch(statsProvider);
    final catNames = ref.watch(categoryNamesProvider);
    String nameOf(String? id) =>
        id == null ? 'Ohne Kategorie' : (catNames[id] ?? 'Ohne Kategorie');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
        actions: [
          IconButton(
            tooltip: 'Budgets',
            icon: const Icon(Icons.savings_outlined),
            onPressed: () => context.go('/budgets'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<StatsPeriod>(
            segments: [
              for (final p in StatsPeriod.values)
                ButtonSegment(value: p, label: Text(p.label)),
            ],
            selected: {period},
            onSelectionChanged: (s) =>
                ref.read(periodFilterProvider.notifier).set(s.first),
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
          _BarSection(
            title: 'Ausgaben nach Kategorie',
            data: stats.expenseByCategory,
            nameOf: nameOf,
            color: Colors.red.shade600,
          ),
          const SizedBox(height: 12),
          _BarSection(
            title: 'Einnahmen nach Kategorie',
            data: stats.incomeByCategory,
            nameOf: nameOf,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_outlined),
                  title: const Text('Gesamtvermögen'),
                  trailing: Text(
                    formatCents(stats.netWorthCents),
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
                  trailing: Text(
                    formatCents(stats.debtCents),
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
            Text(
              formatCents(cents),
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

class _BarSection extends StatelessWidget {
  const _BarSection({
    required this.title,
    required this.data,
    required this.nameOf,
    required this.color,
  });

  final String title;
  final Map<String?, int> data;
  final String Function(String?) nameOf;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 0 : entries.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('Keine Daten.')
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(nameOf(e.key),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(formatCents(e.value),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : e.value / max,
                          minHeight: 8,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
