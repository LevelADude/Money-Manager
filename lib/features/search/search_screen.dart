import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../transactions/transaction_providers.dart';

/// Globale Suche über alle Buchungen (zeitraumübergreifend) und Konten.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final txs =
        ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');

    final matchedAccounts = q.isEmpty
        ? const <Account>[]
        : accounts.where((a) => a.name.toLowerCase().contains(q)).toList();

    final matchedTx = q.isEmpty
        ? const <AppTransaction>[]
        : (txs.where((t) {
            final hay = [
              t.title,
              t.note,
              ...t.tags,
              accountNames[t.accountId] ?? '',
              t.categoryId == null ? '' : (catNames[t.categoryId] ?? ''),
            ].join(' ').toLowerCase();
            return hay.contains(q) || centsToInput(t.amountCents).contains(q);
          }).toList()..sort((a, b) => b.occurredOn.compareTo(a.occurredOn)));

    final limitedTx = matchedTx.take(100).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l.searchFieldHint,
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _query.clear()),
            ),
        ],
      ),
      body: q.isEmpty
          ? Center(child: Text(l.enterSearchTerm))
          : (matchedAccounts.isEmpty && limitedTx.isEmpty)
          ? Center(child: Text(l.noResults))
          : ListView(
              children: [
                if (matchedAccounts.isNotEmpty) ...[
                  _Header(l.navAccounts),
                  for (final a in matchedAccounts)
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: Text(a.name),
                      onTap: () => context.go('/account/${a.id}'),
                    ),
                ],
                if (limitedTx.isNotEmpty) ...[
                  _Header('${l.navTransactions} (${matchedTx.length})'),
                  for (final t in limitedTx)
                    ListTile(
                      leading: Icon(switch (t.type) {
                        TransactionType.income => Icons.south_west,
                        TransactionType.expense => Icons.north_east,
                        TransactionType.transfer => Icons.swap_horiz,
                      }),
                      title: Text(
                        t.title.isEmpty
                            ? (t.categoryId == null
                                  ? l.transactionType(t.type)
                                  : (catNames[t.categoryId] ??
                                        l.transactionType(t.type)))
                            : t.title,
                      ),
                      subtitle: Text(
                        '${df.format(t.occurredOn)} · '
                        '${accountNames[t.accountId] ?? ''}',
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
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
