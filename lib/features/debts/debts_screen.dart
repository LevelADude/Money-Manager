import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/balances.dart';
import '../../shared/mini_line_chart.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../archive/archive_providers.dart';
import '../transactions/transaction_providers.dart';
import '../../core/theme.dart';
import '../../shared/bento.dart';

/// Schulden-/Kredit-Tracker: Restschuld + Verlauf je Verbindlichkeits-Konto
/// (Kreditkarte / Kredit), inkl. Kreditrahmen-Auslastung.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final txs =
        ref.watch(allTransactionsProvider).value ?? const <AppTransaction>[];
    final carryover = ref.watch(archivedCarryoverProvider);
    // Salden aller Konten in einem Durchlauf (gecacht) statt pro Konto erneut.
    final balances = ref.watch(accountBalancesProvider);
    final liabilities = accounts
        .where((a) => a.type.isLiability && !a.archived)
        .toList();

    final totalDebt = liabilities.fold<int>(0, (s, a) {
      final b = balances[a.id] ?? 0;
      return s + (b < 0 ? -b : 0);
    });

    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.moreDebts)),
      body: liabilities.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noDebtAccounts),
              ),
            )
          : ListView(
              padding: BentoListView.paddingOf(context),
              children: [
                BentoGrid(
                  cells: [
                    BentoCell.full(
                      child: BentoStat(
                        label: l.totalDebt,
                        trailing: const Icon(Icons.trending_down, size: 18),
                        value: MoneyText(
                          totalDebt,
                          style: TextStyle(
                            color: totalDebt > 0
                                ? AppColors.of(context).expense
                                : null,
                          ),
                        ),
                      ),
                    ),
                    // Schmal untereinander, breit zwei Konten nebeneinander.
                    for (final a in liabilities)
                      BentoCell(
                        span: 2,
                        wideSpan: 2,
                        child: _DebtTile(
                          account: a,
                          currentCents: balances[a.id] ?? 0,
                          txs: txs,
                          carryover: carryover,
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Ein Schulden-Konto: Saldo, Auslastung des Kreditrahmens und der Verlauf
/// der Restschuld über zwölf Monate am Kachelboden.
class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.account,
    required this.currentCents,
    required this.txs,
    required this.carryover,
  });

  final Account account;

  /// Aktueller Saldo, zentral vorberechnet (siehe `accountBalancesProvider`).
  final int currentCents;
  final List<AppTransaction> txs;
  final Map<String, int> carryover;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppColors.of(context);
    // Aktueller Saldo (negativ = Schuld).
    final current = currentCents;
    final debt = current < 0 ? -current : 0;

    // Restschuld-Verlauf: Saldo zum Monatsende der letzten 12 Monate.
    final now = DateTime.now();
    final series = <int>[];
    for (var i = 11; i >= 0; i--) {
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);
      series.add(accountBalanceAsOf(account, txs, carryover, monthEnd));
    }

    final limit = account.creditLimitCents;
    final utilization = (limit != null && limit > 0)
        ? (debt / limit).clamp(0.0, 1.0)
        : null;

    return BentoTile(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.name,
                  style: Bento.label(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    current,
                    style: Bento.number(
                      context,
                      size: 28,
                    ).copyWith(color: current < 0 ? c.expense : null),
                  ),
                ),
                if (utilization != null) ...[
                  const SizedBox(height: 12),
                  BentoProgress(
                    value: utilization,
                    color: utilization >= 0.9 ? c.expense : c.warning,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.creditUtilization,
                          style: Bento.sub(context),
                        ),
                      ),
                      Text(
                        '${(utilization * 100).round()} %',
                        style: Bento.sub(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Text(l.debtTrend12, style: Bento.sub(context)),
              ],
            ),
          ),
          // Verlauf am Kachelboden, auch wenn die Nachbarkachel höher ist.
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MiniLineChart(
              values: series,
              color: Theme.of(context).colorScheme.primary,
              height: 80,
            ),
          ),
        ],
      ),
    );
  }
}
