import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/recurring_rule.dart';
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
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Daueraufträge')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/recurring/new'),
        icon: const Icon(Icons.add),
        label: const Text('Dauerauftrag'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Daueraufträge.\nLege z. B. Miete oder Gehalt an.',
                  textAlign: TextAlign.center,
                ),
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
                      ? (catNames[r.categoryId] ?? r.type.label)
                      : r.type.label);
              final acc = accountNames[r.accountId] ?? '';
              final sub = '$acc · alle ${r.intervalCount} ${r.intervalUnit.label}'
                  ' · nächste: ${df.format(r.nextDue)}'
                  '${r.active ? '' : ' · pausiert'}';
              return ListTile(
                onTap: () => context.go('/recurring/${r.id}/edit'),
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
                    Text(formatCents(r.amountCents),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
