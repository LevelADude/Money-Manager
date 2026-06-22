import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/balances.dart';
import '../../shared/category_icons.dart';
import '../../shared/data_refresh.dart';
import '../../shared/money_text.dart';
import '../auth/auth_providers.dart';
import '../currency/currency_providers.dart';
import '../profile/profile_providers.dart';
import '../profile/profile_switcher.dart';
import '../archive/archive_providers.dart';
import '../recurring/recurring_providers.dart';
import '../reminders/reminders_providers.dart';
import '../sharing/account_member_providers.dart';
import '../transactions/person_filter.dart';
import '../transactions/transaction_providers.dart';
import 'account_providers.dart';

/// "Konten"-Tab: Gesamtvermögen + Konten, nach Kontokategorie gruppiert
/// (mit Summe je Kategorie).
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  // Anzeige-Reihenfolge der Kontotypen (Vermögenswerte zuerst, Schulden zuletzt).
  static const List<AccountType> _order = [
    AccountType.bank,
    AccountType.cash,
    AccountType.savings,
    AccountType.wallet,
    AccountType.investment,
    AccountType.other,
    AccountType.creditCard,
    AccountType.loan,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fällige Daueraufträge beim App-Start einmalig erzeugen.
    ref.watch(recurringGenerationProvider);

    final accountsAsync = ref.watch(accountsProvider);
    final personFilter = ref.watch(personFilterProvider);
    final myId = ref.watch(currentUserIdProvider);
    // Eigene Konten kann man nur in der Eigen-/Gesamtansicht anlegen.
    final canAddAccount = personFilter == null || personFilter == myId;
    final readOnly = ref.watch(isReadOnlyProvider).asData?.value ?? false;
    final convert = ref.watch(converterProvider);
    final txs =
        ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final carryover = ref.watch(archivedCarryoverProvider);
    final memberNames =
        ref.watch(profileNamesProvider).asData?.value ??
        const <String, String>{};
    final l = AppLocalizations.of(context);

    int balanceOf(Account a) => accountBalanceCents(a, txs, carryover);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navAccounts),
        actions: [
          const ProfileSwitcher(),
          IconButton(
            tooltip: l.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              refreshAllData(ref);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l.refreshed)));
            },
          ),
          Builder(
            builder: (context) {
              final count = ref.watch(remindersProvider).length;
              return IconButton(
                tooltip: l.moreReminders,
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => context.go('/more/reminders'),
              );
            },
          ),
          IconButton(
            tooltip: l.moreSearch,
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/more/search'),
          ),
          IconButton(
            tooltip: l.sortAccounts,
            icon: const Icon(Icons.swap_vert),
            onPressed: () => context.go('/account/reorder'),
          ),
        ],
      ),
      floatingActionButton: (readOnly || !canAddAccount)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/account/new'),
              icon: const Icon(Icons.add),
              label: Text(l.accountFab),
            ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e))),
        data: (allAccounts) {
          // Konten der gewählten Person inkl. geteilter Konten (null = alle).
          final accounts = ref.watch(personFilteredAccountsProvider);
          final membersByAccount = ref.watch(membersByAccountProvider);
          if (accounts.isEmpty) {
            return Center(child: Text(l.noAccounts));
          }
          final byType = <AccountType, List<Account>>{};
          for (final a in accounts) {
            byType.putIfAbsent(a.type, () => []).add(a);
          }

          final children = <Widget>[
            _NetWorthCard(
              totalCents: ref.watch(netWorthProvider(personFilter)),
            ),
          ];

          // Vermögen je Person nur in der Gesamtansicht („Alle Personen").
          final owners = <String>{
            for (final a in accounts)
              if (a.ownerId != null) a.ownerId!,
          }.toList();
          if (personFilter == null && owners.length > 1) {
            final entries = [
              for (final o in owners)
                (
                  name: memberNames[o]?.isNotEmpty == true
                      ? memberNames[o]!
                      : l.unknownPerson,
                  cents: ref.watch(netWorthProvider(o)),
                ),
            ]..sort((a, b) => b.cents.compareTo(a.cents));
            children.add(_PerPersonCard(entries: entries));
          }
          for (final type in _order) {
            final group = byType[type];
            if (group == null || group.isEmpty) continue;
            final subtotal = group.fold<int>(
              0,
              (s, a) => s + convert(balanceOf(a), a.currency),
            );
            children.add(
              _CategoryHeader(
                label: l.accountType(type),
                cents: subtotal,
                isLiability: type.isLiability,
              ),
            );
            for (final a in group) {
              children.add(
                _AccountTile(
                  account: a,
                  balanceCents: balanceOf(a),
                  currency: a.currency,
                  ownerName: memberNames[a.ownerId] ?? '',
                  shared: membersByAccount[a.id]?.isNotEmpty ?? false,
                  onTap: () => context.go('/account/${a.id}'),
                  onEdit: () => context.go('/account/${a.id}/edit'),
                  onArchive: () async {
                    await ref
                        .read(accountRepositoryProvider)
                        .setArchived(id: a.id, archived: !a.archived);
                    ref.invalidate(accountsProvider);
                  },
                  onDelete: () => _confirmDelete(context, ref, a),
                ),
              );
            }
          }
          return ListView(children: children);
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Account a,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteAccountTitle(a.name)),
        content: Text(l.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(accountRepositoryProvider).deleteAccount(a.id);
      ref.invalidate(accountsProvider);
      ref.invalidate(allTransactionsProvider);
    }
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({required this.totalCents});

  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final positive = totalCents >= 0;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context).netWorth,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            MoneyText(
              totalCents,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: positive ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerPersonCard extends StatelessWidget {
  const _PerPersonCard({required this.entries});

  final List<({String name, int cents})> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context).wealthPerPerson,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(e.name, overflow: TextOverflow.ellipsis),
                    ),
                    MoneyText(
                      e.cents,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: e.cents < 0 ? Colors.red.shade700 : null,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.label,
    required this.cents,
    required this.isLiability,
  });

  final String label;
  final int cents;
  final bool isLiability;

  @override
  Widget build(BuildContext context) {
    final negative = cents < 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          MoneyText(
            cents,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: negative ? Colors.red.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.balanceCents,
    required this.currency,
    required this.ownerName,
    required this.shared,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final Account account;
  final int balanceCents;
  final String currency;
  final String ownerName;
  final bool shared;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final negative = balanceCents < 0;
    final subtitle = [
      if (ownerName.isNotEmpty) ownerName,
      if (shared) l.sharedLabel,
      if (account.archived) l.archivedLabel,
    ].join('  ·  ');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Icon(iconForAccountType(accountTypeToDb(account.type))),
      ),
      title: Text(account.name, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            balanceCents,
            currency: currency,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: negative ? Colors.red.shade700 : null,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  onEdit();
                case 'archive':
                  onArchive();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l.edit),
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  leading: Icon(
                    account.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  title: Text(account.archived ? l.activate : l.archive),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
