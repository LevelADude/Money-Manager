import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../categories/category_providers.dart';
import '../profile/profile_providers.dart';
import '../transactions/transaction_providers.dart';
import 'ledger_providers.dart';

/// Detailansicht eines Buchs: Saldo + Liste der Buchungen.
class LedgerDetailScreen extends ConsumerWidget {
  const LedgerDetailScreen({super.key, required this.ledgerId});

  final String ledgerId;

  String _ledgerName(WidgetRef ref) {
    final list = ref.watch(ledgersProvider).asData?.value;
    if (list != null) {
      for (final l in list) {
        if (l.id == ledgerId) return l.name;
      }
    }
    return 'Buch';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsProvider(ledgerId));
    final categoryNames = <String, String>{
      for (final c
          in ref.watch(categoriesProvider(ledgerId)).asData?.value ??
              const <Category>[])
        c.id: c.name,
    };
    final memberNames =
        ref.watch(profileNamesProvider).asData?.value ?? const <String, String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(_ledgerName(ref)),
        actions: [
          IconButton(
            tooltip: 'Kategorien verwalten',
            icon: const Icon(Icons.label_outline),
            onPressed: () => context.go('/ledger/$ledgerId/categories'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/ledger/$ledgerId/new'),
        icon: const Icon(Icons.add),
        label: const Text('Buchung'),
      ),
      body: txs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (items) {
          final balance =
              items.fold<double>(0, (sum, t) => sum + t.signedAmount);
          return Column(
            children: [
              _BalanceHeader(balance: balance),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Noch keine Buchungen.'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final tx = items[i];
                          return _TransactionTile(
                            tx: tx,
                            categoryName: tx.categoryId == null
                                ? null
                                : categoryNames[tx.categoryId],
                            authorName: memberNames[tx.createdBy],
                            onTap: () =>
                                context.go('/ledger/$ledgerId/edit/${tx.id}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final positive = balance >= 0;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('Saldo', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            fmt.format(balance),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: positive ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
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
    required this.categoryName,
    required this.authorName,
    required this.onTap,
  });

  final AppTransaction tx;
  final String? categoryName;
  final String? authorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final df = DateFormat('dd.MM.yyyy');
    final income = tx.direction == TransactionDirection.income;
    final parts = <String>[
      df.format(tx.occurredOn),
      ?categoryName,
      if (authorName != null && authorName!.isNotEmpty) 'von $authorName',
    ];
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: income ? Colors.green.shade100 : Colors.red.shade100,
        child: Icon(
          income ? Icons.south_west : Icons.north_east,
          color: income ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
      title: Text(
        tx.note.isEmpty ? (income ? 'Einnahme' : 'Ausgabe') : tx.note,
      ),
      subtitle: Text(parts.join('  ·  ')),
      trailing: Text(
        fmt.format(tx.signedAmount),
        style: TextStyle(
          color: income ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
