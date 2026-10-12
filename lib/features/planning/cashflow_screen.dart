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

    return Scaffold(
      appBar: AppBar(
        title: Text(l.moreCashflow),
        actions: const [ProfileSwitcher()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.currentBalance,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  MoneyText(
                    current,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.lowestBalance60,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      MoneyText(
                        lowest,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: lowest < 0 ? Colors.red.shade700 : null,
                        ),
                      ),
                    ],
                  ),
                  if (lowest < 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l.balanceGoesNegative,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.noPlannedTx60),
              ),
            )
          else
            for (final r in rows)
              ListTile(
                dense: true,
                leading: Icon(
                  r.signed >= 0 ? Icons.south_west : Icons.north_east,
                  color: r.signed >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                title: Text(r.title),
                subtitle: Text(df.format(r.date)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      r.signed.abs(),
                      prefix: r.signed >= 0 ? '+' : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: r.signed >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    MoneyText(
                      r.balance,
                      style: TextStyle(
                        fontSize: 12,
                        color: r.balance < 0
                            ? Colors.red.shade700
                            : Theme.of(context).hintColor,
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
