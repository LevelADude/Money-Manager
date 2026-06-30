import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/mini_line_chart.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../statistics/statistics_providers.dart';

/// Was-wäre-wenn: spielt verschiedene Einnahmen/Ausgaben-Szenarien durch und
/// zeigt die Vermögensentwicklung über 12 Monate.
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

  void _prefill() {
    if (_prefilled) return;
    final months = ref.read(monthlyTotalsProvider);
    final withData = months
        .where((m) => m.incomeCents > 0 || m.expenseCents > 0)
        .toList();
    final n = withData.isEmpty ? 1 : withData.length;
    final avgIncome = withData.fold<int>(0, (s, m) => s + m.incomeCents) ~/ n;
    final avgExpense = withData.fold<int>(0, (s, m) => s + m.expenseCents) ~/ n;
    _income.text = centsToInput(avgIncome);
    _expense.text = centsToInput(avgExpense);
    _prefilled = true;
  }

  @override
  Widget build(BuildContext context) {
    _prefill();
    final income = parseToCents(_income.text) ?? 0;
    final expense = parseToCents(_expense.text) ?? 0;
    final effExpense = (expense * (1 - _reducePct / 100)).round();
    final surplus = income - effExpense;
    final current = ref.watch(netWorthProvider(null));
    final projection = [for (var i = 1; i <= 12; i++) current + surplus * i];
    final inOneYear = current + surplus * 12;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.moreSimulator)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.simulatorIntro),
          const SizedBox(height: 16),
          TextField(
            controller: _income,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.incomePerMonth,
              prefixIcon: const Icon(Icons.south_west),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _expense,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.expensePerMonth,
              prefixIcon: const Icon(Icons.north_east),
            ),
          ),
          const SizedBox(height: 8),
          Text(l.reduceExpenses(_reducePct.round())),
          Slider(
            value: _reducePct,
            max: 50,
            divisions: 50,
            label: '${_reducePct.round()} %',
            onChanged: (v) => setState(() => _reducePct = v),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(context, l.effectiveExpenses, effExpense),
                  _row(context, l.surplusPerMonth, surplus, bold: true),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.wealthIn12Months,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      MoneyText(
                        inOneYear,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: inOneYear >= current
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  MoneyText(
                    inOneYear - current,
                    prefix: l.wealthChangePrefix((inOneYear - current) >= 0),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(l.projection, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          MiniLineChart(
            values: projection,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int cents, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          MoneyText(
            cents,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }
}
