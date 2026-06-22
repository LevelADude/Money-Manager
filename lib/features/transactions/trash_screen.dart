import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(l.moreTrash)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e))),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.trashEmpty),
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
                      ? l.transactionType(tx.type)
                      : (catNames[tx.categoryId] ?? l.transactionType(tx.type)))
                  : tx.title;
              return ListTile(
                title: Text(title),
                subtitle: Text(
                    l.deletedOn(df.format(items[i].deletedAt.toLocal()))),
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
                      tooltip: l.restore,
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
                      tooltip: l.purge,
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
