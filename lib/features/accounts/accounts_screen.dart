import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../shared/category_icons.dart';
import '../../shared/money_text.dart';
import '../currency/currency_providers.dart';
import '../profile/profile_providers.dart';
import '../profile/profile_switcher.dart';
import '../recurring/recurring_providers.dart';
import '../reminders/reminders_providers.dart';
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
    final readOnly = ref.watch(isReadOnlyProvider).asData?.value ?? false;
    final convert = ref.watch(converterProvider);
    final txs = ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final memberNames =
        ref.watch(profileNamesProvider).asData?.value ?? const <String, String>{};

    int balanceOf(Account a) {
      var s = a.openingBalanceCents;
      for (final t in txs) {
        s += t.signedCentsFor(a.id);
      }
      return s;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konten'),
        actions: [
          const ProfileSwitcher(),
          Builder(builder: (context) {
            final count = ref.watch(remindersProvider).length;
            return IconButton(
              tooltip: 'Erinnerungen',
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => context.go('/more/reminders'),
            );
          }),
          IconButton(
            tooltip: 'Suche',
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/more/search'),
          ),
          IconButton(
            tooltip: 'Konten sortieren',
            icon: const Icon(Icons.swap_vert),
            onPressed: () => context.go('/account/reorder'),
          ),
        ],
      ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/account/new'),
              icon: const Icon(Icons.add),
              label: const Text('Konto'),
            ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (allAccounts) {
          // Nur die Konten der gewählten Person (null = alle Personen).
          final accounts = personFilter == null
              ? allAccounts
              : allAccounts.where((a) => a.ownerId == personFilter).toList();
          if (accounts.isEmpty) {
            return const Center(
              child: Text('Noch keine Konten. Lege unten eines an.'),
            );
          }
          final byType = <AccountType, List<Account>>{};
          for (final a in accounts) {
            byType.putIfAbsent(a.type, () => []).add(a);
          }

          final children = <Widget>[
            _NetWorthCard(totalCents: ref.watch(netWorthProvider(personFilter))),
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
                      : 'Unbekannt',
                  cents: ref.watch(netWorthProvider(o)),
                ),
            ]..sort((a, b) => b.cents.compareTo(a.cents));
            children.add(_PerPersonCard(entries: entries));
          }
          for (final type in _order) {
            final group = byType[type];
            if (group == null || group.isEmpty) continue;
            final subtotal = group.fold<int>(
                0, (s, a) => s + convert(balanceOf(a), a.currency));
            children.add(_CategoryHeader(
              label: type.label,
              cents: subtotal,
              isLiability: type.isLiability,
            ));
            for (final a in group) {
              children.add(_AccountTile(
                account: a,
                balanceCents: balanceOf(a),
                currency: a.currency,
                ownerName: memberNames[a.ownerId] ?? '',
                onTap: () => context.go('/account/${a.id}'),
                onEdit: () => context.go('/account/${a.id}/edit'),
                onArchive: () async {
                  await ref
                      .read(accountRepositoryProvider)
                      .setArchived(id: a.id, archived: !a.archived);
                  ref.invalidate(accountsProvider);
                },
                onDelete: () => _confirmDelete(context, ref, a),
              ));
            }
          }
          return ListView(children: children);
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('„${a.name}" löschen?'),
        content: const Text(
          'Alle Buchungen dieses Kontos werden ebenfalls entfernt. '
          'Das kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
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
            Text('Gesamtvermögen',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            MoneyText(
              totalCents,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        positive ? Colors.green.shade700 : Colors.red.shade700,
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
            Text('Vermögen je Person',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
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
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
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
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final Account account;
  final int balanceCents;
  final String currency;
  final String ownerName;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final negative = balanceCents < 0;
    final subtitle = [
      if (ownerName.isNotEmpty) ownerName,
      if (account.archived) 'archiviert',
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
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Bearbeiten'),
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  leading: Icon(account.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined),
                  title: Text(account.archived ? 'Aktivieren' : 'Archivieren'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Löschen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
