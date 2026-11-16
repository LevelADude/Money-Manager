import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/recurring_rule.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../currency/currency_providers.dart';
import '../profile/profile_switcher.dart';
import '../recurring/recurring_providers.dart';
import '../reservations/reservation_providers.dart';
import '../transactions/person_filter.dart';
import 'cashflow_projection.dart';
import '../../core/theme.dart';
import '../../shared/bento.dart';

/// Cashflow-Kalender: prognostizierter Kontostand anhand der kommenden
/// Daueraufträge und fälliger Reservierungen (nächste 60 Tage), für dieselbe
/// Person/Konten-Auswahl wie der Konten-Tab und in Hauptwährung.
class CashflowScreen extends ConsumerWidget {
  const CashflowScreen({super.key});

  static const _horizonDays = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gleicher Umfang wie der Konten-Tab: gewählte Person (eigene + geteilte
    // Konten), nur Konten im Vermögen, alles in Hauptwährung.
    final accounts = ref.watch(personFilteredAccountsProvider);
    final rules =
        ref.watch(recurringRulesProvider).value ?? const <RecurringRule>[];
    final l = AppLocalizations.of(context);
    final df = DateFormat('EEEE, dd.MM.yyyy', 'de');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final projection = projectCashflow(
      accounts: accounts,
      balances: ref.watch(accountBalancesProvider),
      rules: rules,
      reservations: ref.watch(reservationsProvider),
      convert: ref.watch(converterProvider),
      today: today,
      horizon: today.add(const Duration(days: _horizonDays)),
      ruleTitle: (r) => r.title.isEmpty ? l.standingOrderNoun : r.title,
      reservationTitle: (r) => l.cashflowReservation(r.name),
    );
    final current = projection.current;
    final events = projection.events;

    // Laufenden Saldo berechnen.
    var running = current;
    final rows = <({DateTime date, String title, int signed, int balance})>[];
    var lowest = current;
    for (final e in events) {
      running += e.signed;
      if (running < lowest) lowest = running;
      rows.add((
        date: e.date,
        title: e.title,
        signed: e.signed,
        balance: running,
      ));
    }

    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    // Saldo-artige Werte nur negativ in Ausgabenfarbe.
    Color? signal(int cents) => cents < 0 ? colors.expense : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.moreCashflow),
        actions: const [ProfileSwitcher()],
      ),
      body: ListView(
        padding: BentoListView.paddingOf(context),
        children: [
          BentoGrid(
            cells: [
              BentoCell(
                span: 1,
                wideSpan: 2,
                child: BentoStat(
                  label: l.currentBalance,
                  value: MoneyText(
                    current,
                    style: TextStyle(color: signal(current)),
                  ),
                ),
              ),
              BentoCell(
                span: 1,
                wideSpan: 2,
                child: BentoStat(
                  label: l.lowestBalance60,
                  value: MoneyText(
                    lowest,
                    style: TextStyle(color: signal(lowest)),
                  ),
                ),
              ),
              if (lowest < 0)
                BentoCell.full(
                  child: BentoTile(
                    child: Row(
                      children: [
                        BentoGlyph(
                          size: 38,
                          tint: colors.expense,
                          child: const Icon(Icons.warning_amber_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.balanceGoesNegative,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Bento.gap),
          if (rows.isEmpty)
            BentoTile(child: Text(l.noPlannedTx60, style: Bento.sub(context)))
          else
            BentoList(
              children: [
                for (final r in rows)
                  BentoRow(
                    leading: BentoGlyph(
                      size: 38,
                      tint: r.signed >= 0 ? colors.income : null,
                      child: Icon(
                        r.signed >= 0 ? Icons.south_west : Icons.north_east,
                      ),
                    ),
                    title: Text(r.title),
                    subtitle: Text(df.format(r.date)),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Einnahmen in Einnahmenfarbe, Ausgaben neutral.
                        MoneyText(
                          r.signed.abs(),
                          prefix: r.signed >= 0 ? '+' : '-',
                          style: TextStyle(
                            color: r.signed >= 0 ? colors.income : null,
                          ),
                        ),
                        // Laufender Saldo danach.
                        MoneyText(
                          r.balance,
                          style: Bento.sub(
                            context,
                          ).copyWith(color: signal(r.balance)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
