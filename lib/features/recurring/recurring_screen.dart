import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import 'recurring_providers.dart';

/// Liste der Daueraufträge (wiederkehrende Buchungen).
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(recurringRulesProvider);
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(l.moreRecurring)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/more/recurring/new'),
        icon: const Icon(Icons.add),
        label: Text(l.recurringFab),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith(e))),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noRecurring, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            itemCount: rules.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = rules[i];
              final income = r.type == TransactionType.income;
              final transfer = r.type == TransactionType.transfer;
              final title = r.title.isNotEmpty
                  ? r.title
                  : (r.categoryId != null
                        ? (catNames[r.categoryId] ?? l.transactionType(r.type))
                        : l.transactionType(r.type));
              final acc = accountNames[r.accountId] ?? '';
              final sub =
                  '$acc · ${l.everyInterval(r.intervalCount, r.intervalUnit)}'
                  ' · ${l.nextDuePrefix(df.format(r.nextDue))}'
                  '${r.active ? '' : ' · ${l.paused}'}';
              return ListTile(
                onTap: () => context.go('/more/recurring/${r.id}/edit'),
                leading: CircleAvatar(
                  backgroundColor: transfer
                      ? null
                      : (income ? Colors.green.shade100 : Colors.red.shade100),
                  child: Icon(
                    transfer
                        ? Icons.swap_horiz
                        : (income ? Icons.south_west : Icons.north_east),
                    color: transfer
                        ? null
                        : (income
                              ? Colors.green.shade700
                              : Colors.red.shade700),
                  ),
                ),
                title: Text(title),
                subtitle: Text(sub),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCents(r.amountCents),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: r.active,
                      onChanged: (v) => ref
                          .read(recurringRepositoryProvider)
                          .setActive(id: r.id, active: v),
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
