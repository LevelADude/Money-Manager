import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../categories/category_providers.dart';
import '../profile/profile_providers.dart';
import '../transactions/transaction_providers.dart';
import 'account_providers.dart';

/// Detailansicht eines Kontos: Saldo + Buchungen.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    String accountName = l.accountLabel;
    for (final a in accounts) {
      if (a.id == accountId) {
        accountName = a.name;
        break;
      }
    }
    final balance = ref.watch(accountBalanceProvider(accountId));
    final txs = ref.watch(accountTransactionsProvider(accountId));
    final categoryNames = ref.watch(categoryNamesProvider);
    final memberNames =
        ref.watch(profileNamesProvider).asData?.value ??
        const <String, String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(accountName),
        actions: [
          IconButton(
            tooltip: l.editAccount,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/account/$accountId/edit'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/account/$accountId/tx/new'),
        icon: const Icon(Icons.add),
        label: Text(l.transactionFab),
      ),
      body: Column(
        children: [
          _BalanceHeader(balanceCents: balance),
          const Divider(height: 1),
          Expanded(
            child: txs.isEmpty
                ? Center(child: Text(l.noTransactions))
                : ListView.separated(
                    itemCount: txs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final tx = txs[i];
                      return _TransactionTile(
                        tx: tx,
                        viewAccountId: accountId,
                        accountNames: accountNames,
                        categoryName: tx.categoryId == null
                            ? null
                            : categoryNames[tx.categoryId],
                        authorName: memberNames[tx.createdBy],
                        onTap: () =>
                            context.go('/account/$accountId/tx/${tx.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.balanceCents});

  final int balanceCents;

  @override
  Widget build(BuildContext context) {
    final negative = balanceCents < 0;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context).balance,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            formatCents(balanceCents),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: negative ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.viewAccountId,
    required this.accountNames,
    required this.categoryName,
    required this.authorName,
    required this.onTap,
  });

  final AppTransaction tx;
  final String viewAccountId;
  final Map<String, String> accountNames;
  final String? categoryName;
  final String? authorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');
    final signed = tx.signedCentsFor(viewAccountId);
    final positive = signed >= 0;

    IconData icon;
    Color color;
    switch (tx.type) {
      case TransactionType.income:
        icon = Icons.south_west;
        color = Colors.green.shade700;
      case TransactionType.expense:
        icon = Icons.north_east;
        color = Colors.red.shade700;
      case TransactionType.transfer:
        icon = Icons.swap_horiz;
        color = positive ? Colors.green.shade700 : Colors.red.shade700;
    }

    String titleText;
    if (tx.title.isNotEmpty) {
      titleText = tx.title;
    } else if (tx.type == TransactionType.transfer) {
      titleText = l.transactionType(TransactionType.transfer);
    } else {
      titleText = categoryName ?? l.transactionType(tx.type);
    }

    final parts = <String>[df.format(tx.occurredOn)];
    if (tx.type == TransactionType.transfer) {
      final other = tx.accountId == viewAccountId
          ? accountNames[tx.transferAccountId]
          : accountNames[tx.accountId];
      if (other != null) {
        parts.add(tx.accountId == viewAccountId ? '→ $other' : '← $other');
      }
    } else if (categoryName != null) {
      parts.add(categoryName!);
    }
    if (authorName != null && authorName!.isNotEmpty) {
      parts.add(l.byAuthor(authorName!));
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(titleText),
      subtitle: Text(parts.join('  ·  ')),
      trailing: Text(
        formatCents(signed),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
