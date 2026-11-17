import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/bento.dart';
import '../../shared/mini_line_chart.dart';
import 'insights_providers.dart';

/// „Insights" – lokal berechnete Auswertungen, gruppiert in Achtung / Überblick
/// / Hinweise. Komplett offline, ohne LLM. Jeder Abschnitt ist eine
/// Listen-Kachel; der Zeitraum-Umschalter bleibt oben stehen.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(insightScopeProvider);
    final insights = ref.watch(localInsightsProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final sections = [
      for (final (section, label) in [
        (InsightSection.warning, l.secWarning),
        (InsightSection.overview, l.secOverview),
        (InsightSection.hint, l.secHint),
      ])
        (
          label,
          [
            for (final i in insights)
              if (i.effectiveSection == section) i,
          ],
        ),
    ].where((s) => s.$2.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.insightsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Bento.margin,
              8,
              Bento.margin,
              8,
            ),
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
            child: ListView(
              padding: BentoListView.paddingOf(context),
              children: [
                if (sections.isEmpty)
                  BentoTile(
                    child: Row(
                      children: [
                        const BentoGlyph(child: Icon(Icons.lightbulb_outline)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.insightsEmpty,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final (i, (label, cards)) in sections.indexed) ...[
                  if (i > 0) const SizedBox(height: Bento.gap * 2),
                  BentoSectionHeader(label: label),
                  BentoList(
                    children: [for (final c in cards) _InsightRow(insight: c)],
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 16, 6, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.insightsLocalNote,
                          style: Bento.sub(context),
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

/// Eine Auswertung als Zeile einer Listen-Kachel: getönter Kreis in der
/// Signalfarbe, Titel, voller Erläuterungstext, optional Verlaufslinie.
class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

  final Insight insight;

  static const double _glyph = 38;
  static const double _glyphGap = 12;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ink2 = t.colorScheme.onSurfaceVariant;
    final color = switch (insight.severity) {
      InsightSeverity.positive => AppColors.of(context).income,
      InsightSeverity.warning => t.colorScheme.error,
      InsightSeverity.info => t.colorScheme.primary,
    };
    final route = insight.route;
    final spark = insight.sparkline;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BentoGlyph(size: _glyph, tint: color, child: Icon(insight.icon)),
              const SizedBox(width: _glyphGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      insight.title,
                      style: t.textTheme.bodyLarge!.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insight.detail,
                      style: t.textTheme.bodySmall!.copyWith(
                        fontSize: 13,
                        height: 1.35,
                        color: ink2,
                      ),
                    ),
                  ],
                ),
              ),
              if (route != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 9),
                  child: Icon(Icons.chevron_right, size: 20, color: ink2),
                ),
            ],
          ),
          if (spark != null && spark.length >= 2)
            Padding(
              // Bündig mit dem Text, nicht mit dem Kreis.
              padding: const EdgeInsets.only(left: _glyph + _glyphGap, top: 10),
              child: MiniLineChart(
                values: spark,
                color: color,
                height: 80,
                labels: insight.sparkLabels ?? const [],
              ),
            ),
        ],
      ),
    );
    return route == null
        ? content
        : InkWell(onTap: () => context.go(route), child: content);
  }
}
