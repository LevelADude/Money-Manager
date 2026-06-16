import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/app_transaction.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(_ledgerName(ref))),
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
                        itemBuilder: (_, i) => _TransactionTile(
                          tx: items[i],
                          onDelete: () => ref
                              .read(transactionRepositoryProvider)
                              .deleteTransaction(items[i].id),
                        ),
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
  const _TransactionTile({required this.tx, required this.onDelete});

  final AppTransaction tx;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final df = DateFormat('dd.MM.yyyy');
    final income = tx.direction == TransactionDirection.income;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            income ? Colors.green.shade100 : Colors.red.shade100,
        child: Icon(
          income ? Icons.south_west : Icons.north_east,
          color: income ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
      title: Text(
        tx.note.isEmpty ? (income ? 'Einnahme' : 'Ausgabe') : tx.note,
      ),
      subtitle: Text(df.format(tx.occurredOn)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fmt.format(tx.signedAmount),
            style: TextStyle(
              color: income ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
