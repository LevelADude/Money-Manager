import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../shared/category_icons.dart';
import '../../shared/money.dart';
import '../profile/profile_providers.dart';
import '../recurring/recurring_providers.dart';
import '../transactions/transaction_providers.dart';
import 'account_providers.dart';

/// Startseite: Gesamtvermögen + Konten, nach Person gruppiert.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fällige Daueraufträge beim App-Start einmalig erzeugen.
    ref.watch(recurringGenerationProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final txs =
        ref.watch(allTransactionsProvider).asData?.value ?? const <AppTransaction>[];
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
          IconButton(
            tooltip: 'Statistik',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => context.go('/statistics'),
          ),
          IconButton(
            tooltip: 'Suche',
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            tooltip: 'Kategorien',
            icon: const Icon(Icons.label_outline),
            onPressed: () => context.go('/categories'),
          ),
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/account/new'),
        icon: const Icon(Icons.add),
        label: const Text('Konto'),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: Text('Noch keine Konten. Lege unten eines an.'),
            );
          }
          // Nach Besitzer gruppieren (Reihenfolge stabil).
          final groups = <String?, List<Account>>{};
          for (final a in accounts) {
            groups.putIfAbsent(a.ownerId, () => []).add(a);
          }

          final total = ref.watch(netWorthProvider(null));

          final children = <Widget>[
            _NetWorthCard(totalCents: total),
          ];
          groups.forEach((ownerId, accs) {
            final ownerName = memberNames[ownerId] ?? 'Unbekannt';
            final subtotal = accs
                .where((a) => a.includeInNetWorth && !a.archived)
                .fold<int>(0, (s, a) => s + balanceOf(a));
            children.add(_GroupHeader(name: ownerName, subtotalCents: subtotal));
            for (final a in accs) {
              children.add(_AccountTile(
                account: a,
                balanceCents: balanceOf(a),
                onTap: () => context.go('/account/${a.id}'),
                onEdit: () => context.go('/account/${a.id}/edit'),
                onArchive: () => ref.read(accountRepositoryProvider).setArchived(
                      id: a.id,
                      archived: !a.archived,
                    ),
                onDelete: () => _confirmDelete(context, ref, a),
              ));
            }
          });

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
            Text(
              formatCents(totalCents),
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.name, required this.subtotalCents});

  final String name;
  final int subtotalCents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(formatCents(subtotalCents),
              style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.balanceCents,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final Account account;
  final int balanceCents;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final negative = balanceCents < 0;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Icon(iconForAccountType(accountTypeToDb(account.type))),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(account.name, overflow: TextOverflow.ellipsis),
          ),
          if (account.archived) ...[
            const SizedBox(width: 8),
            Text('· archiviert',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
      subtitle: Text(account.type.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCents(balanceCents),
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
