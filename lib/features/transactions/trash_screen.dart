import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/app_transaction.dart';
import '../../shared/money_text.dart';
import '../categories/category_providers.dart';
import 'transaction_providers.dart';

/// Papierkorb: gelöschte Buchungen wiederherstellen oder endgültig löschen.
/// Einträge älter als 30 Tage werden automatisch entfernt.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deletedTransactionsProvider);
    final catNames = ref.watch(categoryNamesProvider);
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Papierkorb')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Papierkorb ist leer.\n\n'
                    'Gelöschte Buchungen erscheinen hier 30 Tage lang und '
                    'können wiederhergestellt werden.'),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final tx = items[i].tx;
              final title = tx.title.isEmpty
                  ? (tx.categoryId == null
                      ? tx.type.label
                      : (catNames[tx.categoryId] ?? tx.type.label))
                  : tx.title;
              return ListTile(
                title: Text(title),
                subtitle: Text(
                    'Gelöscht am ${df.format(items[i].deletedAt.toLocal())}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoneyText(
                      tx.amountCents,
                      prefix: switch (tx.type) {
                        TransactionType.income => '+',
                        TransactionType.expense => '-',
                        TransactionType.transfer => '',
                      },
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      tooltip: 'Wiederherstellen',
                      icon: const Icon(Icons.restore_from_trash),
                      onPressed: () async {
                        await ref
                            .read(transactionRepositoryProvider)
                            .restoreTransaction(tx.id);
                        ref.invalidate(deletedTransactionsProvider);
                        ref.invalidate(allTransactionsProvider);
                      },
                    ),
                    IconButton(
                      tooltip: 'Endgültig löschen',
                      icon: const Icon(Icons.delete_forever),
                      onPressed: () async {
                        await ref
                            .read(transactionRepositoryProvider)
                            .purgeTransaction(tx.id);
                        ref.invalidate(deletedTransactionsProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
