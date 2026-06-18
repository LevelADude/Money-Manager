import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/recurring_rule.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../recurring/recurring_providers.dart';
import '../transactions/transaction_providers.dart';

/// Cashflow-Kalender: prognostizierter Kontostand anhand der kommenden
/// Daueraufträge (nächste 60 Tage).
class CashflowScreen extends ConsumerWidget {
  const CashflowScreen({super.key});

  static const _horizonDays = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final txs = ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final rules = ref.watch(recurringRulesProvider).asData?.value ??
        const <RecurringRule>[];
    final df = DateFormat('EEEE, dd.MM.yyyy', 'de');

    // Aktueller Gesamt-Kontostand (nicht archivierte Konten).
    var current = 0;
    for (final a in accounts) {
      if (a.archived) continue;
      var b = a.openingBalanceCents;
      for (final t in txs) {
        b += t.signedCentsFor(a.id);
      }
      current += b;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: _horizonDays));

    // Kommende Dauerauftrags-Vorkommen erzeugen.
    final events = <({DateTime date, String title, int signed})>[];
    for (final r in rules) {
      if (!r.active) continue;
      final count = r.intervalCount < 1 ? 1 : r.intervalCount;
      var d = r.nextDue;
      var guard = 0;
      while (d.isBefore(today) && guard < 1000) {
        d = advanceDate(d, r.intervalUnit, count);
        guard++;
      }
      while (!d.isAfter(horizon) &&
          (r.endDate == null || !d.isAfter(r.endDate!)) &&
          guard < 1000) {
        final signed = switch (r.type) {
          TransactionType.income => r.amountCents,
          TransactionType.expense => -r.amountCents,
          TransactionType.transfer => 0,
        };
        if (signed != 0) {
          events.add((
            date: d,
            title: r.title.isEmpty ? 'Dauerauftrag' : r.title,
            signed: signed,
          ));
        }
        d = advanceDate(d, r.intervalUnit, count);
        guard++;
      }
    }
    events.sort((a, b) => a.date.compareTo(b.date));

    // Laufenden Saldo berechnen.
    var running = current;
    final rows = <({DateTime date, String title, int signed, int balance})>[];
    var lowest = current;
    for (final e in events) {
      running += e.signed;
      if (running < lowest) lowest = running;
      rows.add((date: e.date, title: e.title, signed: e.signed, balance: running));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cashflow-Kalender')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Aktueller Kontostand',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  MoneyText(current,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tiefststand (60 Tage)',
                          style: Theme.of(context).textTheme.bodySmall),
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
                        'Achtung: Der prognostizierte Kontostand wird negativ.',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Keine geplanten Buchungen in den nächsten 60 Tagen. '
                    'Lege Daueraufträge unter „Mehr → Daueraufträge" an.'),
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
