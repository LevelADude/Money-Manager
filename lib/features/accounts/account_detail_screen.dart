import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import '../categories/category_providers.dart';
import '../profile/profile_providers.dart';
import '../reservations/reservation_providers.dart';
import '../reservations/reservation_tile.dart';
import '../reservations/reserved_hint.dart';
import '../settings/settings_providers.dart';
import '../transactions/transaction_providers.dart';
import 'account_providers.dart';

/// Detailansicht eines Kontos: Saldo (verfügbar/gesamt), Reservierungen und
/// Buchungen.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    final accountName = account?.name ?? l.accountLabel;
    final currency = account?.currency ?? gBaseCurrency;
    final balance = ref.watch(accountBalanceProvider(accountId));
    final reservations = ref.watch(accountReservationsProvider(accountId));
    final reserved = ref.watch(reservedByAccountProvider)[accountId] ?? 0;
    final overReserved = ref
        .watch(overReservedAccountsProvider)
        .contains(accountId);
    final readOnly = ref.watch(isReadOnlyProvider).value ?? false;
    final canManage =
        !readOnly &&
        ref.watch(manageableAccountsProvider).any((a) => a.id == accountId);
    final txs = ref.watch(accountTransactionsProvider(accountId));
    final categoryNames = ref.watch(categoryNamesProvider);
    final memberNames =
        ref.watch(profileNamesProvider).value ?? const <String, String>{};

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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          _BalanceHeader(
            balanceCents: balance,
            reservedCents: reserved,
            currency: currency,
            creditLimitCents: account?.creditLimitCents,
            overReserved: overReserved,
          ),
          const Divider(height: 1),
          _ReservationsHeader(
            count: reservations.length,
            onAdd: canManage
                ? () => context.go('/account/$accountId/reservation/new')
                : null,
          ),
          for (final r in reservations)
            ReservationTile(
              reservation: r,
              currency: currency,
              canManage: canManage,
              onEdit: () =>
                  context.go('/account/$accountId/reservation/${r.id}'),
            ),
          if (reservations.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                l.noReservations,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.navTransactions,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l.noTransactions)),
            )
          else
            for (final (i, tx) in txs.indexed) ...[
              if (i > 0) const Divider(height: 1),
              _TransactionTile(
                tx: tx,
                viewAccountId: accountId,
                accountNames: accountNames,
                categoryName: tx.categoryId == null
                    ? null
                    : categoryNames[tx.categoryId],
                authorName: memberNames[tx.createdBy],
                onTap: () => context.go('/account/$accountId/tx/${tx.id}'),
              ),
            ],
        ],
      ),
    );
  }
}

class _BalanceHeader extends ConsumerWidget {
  const _BalanceHeader({
    required this.balanceCents,
    required this.reservedCents,
    required this.currency,
    required this.creditLimitCents,
    required this.overReserved,
  });

  final int balanceCents;
  final int reservedCents;
  final String currency;
  final int? creditLimitCents;
  final bool overReserved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final showAvailable = ref.watch(
      settingsProvider.select((s) => s.showAvailable),
    );
    final primary = primaryAmount(balanceCents, reservedCents, showAvailable);
    final negative = primary < 0;
    final label = showAvailable && reservedCents != 0
        ? l.availableBalance
        : l.balance;
    final limit = creditLimitCents;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          MoneyText(
            primary,
            currency: currency,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: negative ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
          ReservedHint(
            totalCents: balanceCents,
            reservedCents: reservedCents,
            currency: currency,
            textAlign: TextAlign.center,
          ),
          if (limit != null && limit > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l.availableCredit}: ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                MoneyText(
                  limit + balanceCents - reservedCents,
                  currency: currency,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (overReserved) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l.overReservedWarning,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReservationsHeader extends StatelessWidget {
  const _ReservationsHeader({required this.count, required this.onAdd});

  final int count;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 0 ? l.reservations : '${l.reservations} ($count)',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (onAdd != null)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l.reserveAction),
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
