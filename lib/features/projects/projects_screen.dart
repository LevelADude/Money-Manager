import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money_text.dart';
import '../transactions/transaction_providers.dart';

/// Reise-/Projekt-Sicht: Übersicht der Ausgaben je Tag (= Projekt/Reise).
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final tags = ref.watch(allTagsProvider);
    final l = AppLocalizations.of(context);

    final stats = <String, ({int expense, int income, int count})>{};
    for (final tag in tags) {
      var exp = 0, inc = 0, cnt = 0;
      final lt = tag.toLowerCase();
      for (final t in txs) {
        if (!t.tags.any((x) => x.toLowerCase() == lt)) continue;
        cnt++;
        if (t.type == TransactionType.expense) exp += t.amountCents;
        if (t.type == TransactionType.income) inc += t.amountCents;
      }
      stats[tag] = (expense: exp, income: inc, count: cnt);
    }
    final sorted = tags.toList()
      ..sort((a, b) => stats[b]!.expense.compareTo(stats[a]!.expense));

    return Scaffold(
      appBar: AppBar(title: Text(l.moreProjects)),
      body: tags.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noTagsYet, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              children: [
                for (final tag in sorted)
                  ListTile(
                    leading: const Icon(Icons.sell_outlined),
                    title: Text(tag),
                    subtitle: Text(l.txCount(stats[tag]!.count)),
                    trailing: MoneyText(stats[tag]!.expense,
                        prefix: '-',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () =>
                        context.go('/more/projects/${Uri.encodeComponent(tag)}'),
                  ),
              ],
            ),
    );
  }
}
