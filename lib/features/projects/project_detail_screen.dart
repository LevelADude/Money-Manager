import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../transactions/transaction_providers.dart';

/// Detailauswertung eines Projekts/einer Reise (alle Buchungen mit dem Tag).
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lt = tag.toLowerCase();
    final txs =
        (ref.watch(allTransactionsProvider).asData?.value ??
                const <AppTransaction>[])
            .where((t) => t.tags.any((x) => x.toLowerCase() == lt))
            .toList()
          ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');

    var income = 0, expense = 0;
    for (final t in txs) {
      if (t.type == TransactionType.income) income += t.amountCents;
      if (t.type == TransactionType.expense) expense += t.amountCents;
    }

    return Scaffold(
      appBar: AppBar(title: Text(tag)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _kpi(context, l.income, income, Colors.green.shade700),
                  _kpi(context, l.expenses, expense, Colors.red.shade700),
                  _kpi(
                    context,
                    l.balance,
                    income - expense,
                    (income - expense) >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final t in txs)
            ListTile(
              dense: true,
              title: Text(
                t.title.isEmpty
                    ? (t.categoryId == null
                          ? l.transactionType(t.type)
                          : (catNames[t.categoryId] ??
                                l.transactionType(t.type)))
                    : t.title,
              ),
              subtitle: Text(
                '${df.format(t.occurredOn)} · ${accountNames[t.accountId] ?? ''}',
              ),
              trailing: MoneyText(
                t.amountCents,
                prefix: switch (t.type) {
                  TransactionType.income => '+',
                  TransactionType.expense => '-',
                  TransactionType.transfer => '',
                },
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => context.go('/transactions/${t.id}'),
            ),
        ],
      ),
    );
  }

  Widget _kpi(BuildContext context, String label, int cents, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        MoneyText(
          cents,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
