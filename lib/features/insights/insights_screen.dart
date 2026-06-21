import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'insights_providers.dart';

/// „Insights" – lokal berechnete Auswertungen (Monatsvergleich, Ausreißer,
/// Sparquote, Budgets, Sparziele, Abo-Erkennung …). Komplett offline, ohne LLM.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(insightScopeProvider);
    final insights = ref.watch(localInsightsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<InsightScope>(
              segments: const [
                ButtonSegment(
                  value: InsightScope.month,
                  label: Text('Dieser Monat'),
                  icon: Icon(Icons.calendar_view_month),
                ),
                ButtonSegment(
                  value: InsightScope.year,
                  label: Text('Dieses Jahr'),
                  icon: Icon(Icons.calendar_today),
                ),
              ],
              selected: {scope},
              onSelectionChanged: (s) =>
                  ref.read(insightScopeProvider.notifier).set(s.first),
            ),
          ),
          Expanded(
            child: insights.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Noch zu wenig Daten für Auswertungen. Erfasse ein paar '
                        'Buchungen – dann erscheinen hier automatisch Hinweise.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    children: [
                      for (final i in insights) _InsightCard(insight: i),
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
                                'Alles wird lokal auf diesem Gerät berechnet – es '
                                'werden keine Daten an Dritte gesendet.',
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
    return Card(
      child: ListTile(
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
    );
  }
}
