import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../profile/profile_providers.dart';
import '../transactions/transaction_providers.dart';

/// „Wer schuldet wem": teilt die Ausgaben des laufenden Monats gleichmäßig auf
/// alle Personen auf und schlägt einen minimalen Ausgleich vor.
class SettleScreen extends ConsumerWidget {
  const SettleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final txs =
        ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final names =
        ref.watch(profileNamesProvider).asData?.value ??
        const <String, String>{};
    final l = AppLocalizations.of(context);

    String nameOf(String id) =>
        names[id]?.isNotEmpty == true ? names[id]! : l.unknownPerson;

    final ownerOf = {for (final a in accounts) a.id: a.ownerId};
    final members = <String>{
      for (final a in accounts)
        if (a.ownerId != null) a.ownerId!,
    }.toList();

    final now = DateTime.now();
    var total = 0;
    final spent = {for (final m in members) m: 0};
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (t.occurredOn.year != now.year || t.occurredOn.month != now.month) {
        continue;
      }
      final owner = ownerOf[t.accountId];
      if (owner == null || !spent.containsKey(owner)) continue;
      spent[owner] = spent[owner]! + t.amountCents;
      total += t.amountCents;
    }

    // Fairer Anteil je Person. Der Ganzzahl-Rest (total % n Cent) wird auf die
    // ersten Personen verteilt, damit die Summe aller Salden exakt 0 ergibt
    // (sonst bliebe ein Rest-Cent im Ausgleichsvorschlag unverteilt).
    final n = members.length;
    final share = n == 0 ? 0 : total ~/ n;
    final remainder = n == 0 ? 0 : total % n;
    final fairShare = <String, int>{
      for (var k = 0; k < n; k++) members[k]: share + (k < remainder ? 1 : 0),
    };
    final balance = {for (final m in members) m: spent[m]! - fairShare[m]!};

    // Minimaler Ausgleich (greedy).
    final plan = <({String from, String to, int amount})>[];
    final bal = Map<String, int>.from(balance);
    final creditors = members.where((m) => bal[m]! > 0).toList()
      ..sort((a, b) => bal[b]!.compareTo(bal[a]!));
    final debtors = members.where((m) => bal[m]! < 0).toList()
      ..sort((a, b) => bal[a]!.compareTo(bal[b]!));
    var i = 0, j = 0;
    while (i < creditors.length && j < debtors.length) {
      final c = creditors[i], d = debtors[j];
      final amt = math.min(bal[c]!, -bal[d]!);
      if (amt > 0) {
        plan.add((from: d, to: c, amount: amt));
        bal[c] = bal[c]! - amt;
        bal[d] = bal[d]! + amt;
      }
      if (bal[c]! <= 0) i++;
      if (bal[d]! >= 0) j++;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.settleTitle)),
      body: members.length < 2
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.settleNeedsTwo),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.sharedExpensesMonth,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        MoneyText(
                          total,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.fairSharePerPerson,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            MoneyText(share),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.balancesPerPerson,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                for (final m in members)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(child: Text(nameOf(m)[0])),
                    title: Text(nameOf(m)),
                    subtitle: MoneyText(spent[m]!, prefix: l.spentPrefix),
                    trailing: MoneyText(
                      balance[m]!,
                      prefix: balance[m]! > 0 ? '+' : '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: balance[m]! >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                const Divider(height: 24),
                Text(
                  l.settleSuggestion,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (plan.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.allSettled),
                  )
                else
                  for (final p in plan)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: const Icon(Icons.arrow_forward),
                        title: Text('${nameOf(p.from)} → ${nameOf(p.to)}'),
                        trailing: MoneyText(
                          p.amount,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                Text(
                  l.settleHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
