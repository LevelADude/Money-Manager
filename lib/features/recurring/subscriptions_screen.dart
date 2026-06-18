import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/recurring_rule.dart';
import '../../shared/money_text.dart';
import 'recurring_providers.dart';

/// Erkannte Abos/wiederkehrende Buchungen mit Vorschlag, sie als Dauerauftrag
/// anzulegen.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(subscriptionSuggestionsProvider);
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Erkannte Abos')),
      body: candidates.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Keine wiederkehrenden Muster erkannt.\n\nSobald sich eine '
                    'Buchung (gleicher Titel + Betrag) regelmäßig wiederholt, '
                    'wird sie hier als Dauerauftrag vorgeschlagen.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final c in candidates)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.autorenew),
                      title: Text(c.title),
                      subtitle: Text(
                          'alle ${c.intervalCount} ${c.intervalUnit.label} · '
                          '${c.occurrences}× erkannt · ab ${df.format(c.nextDue)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          MoneyText(c.amountCents,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(recurringRepositoryProvider)
                                  .createRule(
                                    accountId: c.accountId,
                                    type: c.type,
                                    amountCents: c.amountCents,
                                    categoryId: c.categoryId,
                                    title: c.title,
                                    intervalUnit: c.intervalUnit,
                                    intervalCount: c.intervalCount,
                                    nextDue: c.nextDue,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Dauerauftrag angelegt')),
                                );
                              }
                            },
                            child: const Text('Anlegen'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
