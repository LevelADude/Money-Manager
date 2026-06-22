import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/app_localizations.dart';
import '../../shared/money_text.dart';
import 'recurring_providers.dart';

/// Erkannte Abos/wiederkehrende Buchungen mit Vorschlag, sie als Dauerauftrag
/// anzulegen.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(subscriptionSuggestionsProvider);
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(l.moreSubscriptions)),
      body: candidates.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noSubscriptions, textAlign: TextAlign.center),
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
                        '${l.everyInterval(c.intervalCount, c.intervalUnit)} · '
                        '${l.detectedTimes(c.occurrences)} · '
                        '${l.fromDate(df.format(c.nextDue))}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          MoneyText(
                            c.amountCents,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                                  SnackBar(content: Text(l.recurringCreated)),
                                );
                              }
                            },
                            child: Text(l.create),
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
