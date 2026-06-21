import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/mini_line_chart.dart';
import 'insights_providers.dart';

/// „Insights" – lokal berechnete Auswertungen, gruppiert in Achtung / Überblick
/// / Hinweise. Komplett offline, ohne LLM.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(insightScopeProvider);
    final insights = ref.watch(localInsightsProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final sections = [
      (InsightSection.warning, l.secWarning),
      (InsightSection.overview, l.secOverview),
      (InsightSection.hint, l.secHint),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.insightsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<InsightScope>(
              segments: [
                ButtonSegment(
                  value: InsightScope.month,
                  label: Text(l.thisMonth),
                  icon: const Icon(Icons.calendar_view_month),
                ),
                ButtonSegment(
                  value: InsightScope.year,
                  label: Text(l.thisYear),
                  icon: const Icon(Icons.calendar_today),
                ),
              ],
              selected: {scope},
              onSelectionChanged: (s) =>
                  ref.read(insightScopeProvider.notifier).set(s.first),
            ),
          ),
          Expanded(
            child: insights.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.insightsEmpty,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    children: [
                      for (final (section, label) in sections)
                        ...() {
                          final cards = insights
                              .where((i) => i.effectiveSection == section)
                              .toList();
                          if (cards.isEmpty) return const <Widget>[];
                          return [
                            _SectionHeader(label: label),
                            for (final i in cards) _InsightCard(insight: i),
                          ];
                        }(),
                      const SizedBox(height: 8),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 16, color: theme.hintColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l.insightsLocalNote,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.hintColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (insight.severity) {
      InsightSeverity.positive => Colors.green.shade600,
      InsightSeverity.warning => scheme.error,
      InsightSeverity.info => scheme.primary,
    };
    final route = insight.route;
    final spark = insight.sparkline;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(insight.icon, color: color),
            ),
            title: Text(insight.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(insight.detail),
            isThreeLine: insight.detail.length > 60,
            trailing:
                route == null ? null : const Icon(Icons.chevron_right, size: 20),
            onTap: route == null ? null : () => context.go(route),
          ),
          if (spark != null && spark.length >= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: MiniLineChart(
                values: spark,
                color: color,
                height: 90,
                labels: insight.sparkLabels ?? const [],
              ),
            ),
        ],
      ),
    );
  }
}
