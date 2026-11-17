import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/bento.dart';
import '../../shared/mini_line_chart.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../statistics/statistics_providers.dart';

/// Was-wäre-wenn: spielt verschiedene Einnahmen/Ausgaben-Szenarien durch und
/// zeigt die Vermögensentwicklung über 12 Monate. Eingaben oben (Felder frei,
/// Regler in einer Kachel), Ergebnis als Summen-Kacheln und Vermögens-Kachel
/// mit Verlaufslinie wie auf der Konten-Seite.
class SimulatorScreen extends ConsumerStatefulWidget {
  const SimulatorScreen({super.key});

  @override
  ConsumerState<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends ConsumerState<SimulatorScreen> {
  final _income = TextEditingController();
  final _expense = TextEditingController();
  double _reducePct = 0;
  bool _prefilled = false;

  @override
  void dispose() {
    _income.dispose();
    _expense.dispose();
    super.dispose();
  }

  /// Belegt die Felder einmalig mit den Monatsdurchschnitten vor – erst,
  /// sobald Buchungen geladen sind (sonst stünde dauerhaft 0 darin), und nie
  /// mehr, nachdem der Nutzer selbst etwas eingegeben hat.
  void _prefill(List<MonthTotals> months) {
    if (_prefilled) return;
    final withData = months
        .where((m) => m.incomeCents > 0 || m.expenseCents > 0)
        .toList();
    if (withData.isEmpty) return;
    final n = withData.length;
    final avgIncome = withData.fold<int>(0, (s, m) => s + m.incomeCents) ~/ n;
    final avgExpense = withData.fold<int>(0, (s, m) => s + m.expenseCents) ~/ n;
    _income.text = centsToInput(avgIncome);
    _expense.text = centsToInput(avgExpense);
    _prefilled = true;
  }

  @override
  Widget build(BuildContext context) {
    _prefill(ref.watch(monthlyTotalsProvider));
    final income = parseToCents(_income.text) ?? 0;
    final expense = parseToCents(_expense.text) ?? 0;
    final effExpense = (expense * (1 - _reducePct / 100)).round();
    final surplus = income - effExpense;
    final current = ref.watch(netWorthProvider(null));
    // Startpunkt plus zwölf Monate, damit die Linie beim heutigen Stand beginnt.
    final projection = [for (var i = 0; i <= 12; i++) current + surplus * i];
    final inOneYear = projection.last;
    final delta = inOneYear - current;
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final c = AppColors.of(context);

    Widget amountField(
      TextEditingController ctrl,
      String label,
      IconData icon,
    ) => TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() => _prefilled = true),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.moreSimulator)),
      body: ListView(
        padding: BentoListView.paddingOf(context),
        children: [
          BentoTile(
            child: Row(
              children: [
                const BentoGlyph(child: Icon(Icons.auto_graph)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.simulatorIntro, style: t.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: Bento.gap * 2),
          BentoColumns(
            left: [amountField(_income, l.incomePerMonth, Icons.south_west)],
            right: [amountField(_expense, l.expensePerMonth, Icons.north_east)],
          ),
          const SizedBox(height: Bento.gap),
          BentoGroup(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            children: [
              Text(
                l.reduceExpenses(_reducePct.round()),
                style: t.textTheme.bodyMedium,
              ),
              Slider(
                value: _reducePct,
                max: 50,
                divisions: 50,
                label: '${_reducePct.round()} %',
                onChanged: (v) => setState(() => _reducePct = v),
              ),
            ],
          ),
          const SizedBox(height: Bento.gap * 2),
          BentoGrid(
            cells: [
              BentoCell(
                wideSpan: 2,
                child: BentoStat(
                  label: l.effectiveExpenses,
                  value: MoneyText(effExpense),
                ),
              ),
              BentoCell(
                wideSpan: 2,
                child: BentoStat(
                  label: l.surplusPerMonth,
                  value: MoneyText(
                    surplus,
                    style: TextStyle(color: surplus < 0 ? c.expense : null),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Bento.gap),
          _WealthTile(
            label: l.wealthIn12Months,
            caption: l.projection,
            cents: inOneYear,
            delta: delta,
            values: projection,
          ),
        ],
      ),
    );
  }
}

/// Vermögen in zwölf Monaten: Kennzahl, Veränderungs-Marke und Verlauf –
/// gleicher Aufbau wie die Gesamtsaldo-Kachel der Konten-Seite.
class _WealthTile extends StatelessWidget {
  const _WealthTile({
    required this.label,
    required this.caption,
    required this.cents,
    required this.delta,
    required this.values,
  });

  final String label;
  final String caption;
  final int cents;
  final int delta;
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Ohne Veränderung wäre die Linie flach am Kachelboden: dann weder Linie
    // noch Marke, wie bei der Gesamtsaldo-Kachel ohne Verlauf.
    final hasTrend = delta != 0;
    return BentoTile(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, hasTrend ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: Bento.label(context))),
                    if (hasTrend)
                      BentoChip(
                        icon: delta >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        child: MoneyText(delta, prefix: delta >= 0 ? '+' : ''),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    cents,
                    style: Bento.number(
                      context,
                      size: 32,
                    ).copyWith(color: cents < 0 ? c.expense : null),
                  ),
                ),
                if (hasTrend) Text(caption, style: Bento.sub(context)),
              ],
            ),
          ),
          if (hasTrend)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: MiniLineChart(
                values: values,
                color: Theme.of(context).colorScheme.primary,
                height: 84,
              ),
            ),
        ],
      ),
    );
  }
}
