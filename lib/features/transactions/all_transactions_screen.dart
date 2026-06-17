import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../shared/money.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import 'transaction_providers.dart';

/// "Buchungen"-Tab: alle Buchungen aller Konten, durchsuch- und filterbar,
/// plus globaler "+"-Button (Konto wählt man im Formular).
class AllTransactionsScreen extends ConsumerStatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  ConsumerState<AllTransactionsScreen> createState() =>
      _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends ConsumerState<AllTransactionsScreen> {
  final _query = TextEditingController();
  TransactionType? _typeFilter;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);
    final df = DateFormat('dd.MM.yyyy');

    final q = _query.text.trim().toLowerCase();
    final results = txs.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (q.isEmpty) return true;
      final cat = t.categoryId == null ? '' : (catNames[t.categoryId] ?? '');
      final acc = accountNames[t.accountId] ?? '';
      return t.title.toLowerCase().contains(q) ||
          t.note.toLowerCase().contains(q) ||
          cat.toLowerCase().contains(q) ||
          acc.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));

    return Scaffold(
      appBar: AppBar(title: const Text('Buchungen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/transactions/new'),
        icon: const Icon(Icons.add),
        label: const Text('Buchung'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Suchen: Titel, Notiz, Kategorie, Konto …',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _query.clear()),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(null, 'Alle'),
                _chip(TransactionType.expense, 'Ausgaben'),
                _chip(TransactionType.income, 'Einnahmen'),
                _chip(TransactionType.transfer, 'Überträge'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('Keine Buchungen.'))
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final t = results[i];
                      final cat =
                          t.categoryId == null ? null : catNames[t.categoryId];
                      final acc = accountNames[t.accountId] ?? '';
                      final sub = [
                        df.format(t.occurredOn),
                        if (acc.isNotEmpty) acc,
                        ?cat,
                      ].join('  ·  ');
                      return ListTile(
                        leading: _icon(t.type),
                        title: Text(
                          t.title.isEmpty ? (cat ?? t.type.label) : t.title,
                        ),
                        subtitle: Text(sub),
                        trailing: Text(
                          _amountText(t),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _color(t),
                          ),
                        ),
                        onTap: () => context.go('/transactions/${t.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(TransactionType? type, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _typeFilter == type,
          onSelected: (_) => setState(() => _typeFilter = type),
        ),
      );

  Widget _icon(TransactionType type) => switch (type) {
        TransactionType.income => CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Icon(Icons.south_west, color: Colors.green.shade700),
          ),
        TransactionType.expense => CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: Icon(Icons.north_east, color: Colors.red.shade700),
          ),
        TransactionType.transfer =>
          const CircleAvatar(child: Icon(Icons.swap_horiz)),
      };

  String _amountText(AppTransaction t) => switch (t.type) {
        TransactionType.income => '+${formatCents(t.amountCents)}',
        TransactionType.expense => '-${formatCents(t.amountCents)}',
        TransactionType.transfer => formatCents(t.amountCents),
      };

  Color? _color(AppTransaction t) => switch (t.type) {
        TransactionType.income => Colors.green.shade700,
        TransactionType.expense => Colors.red.shade700,
        TransactionType.transfer => null,
      };
}
