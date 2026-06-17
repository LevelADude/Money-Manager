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

enum _PeriodView { day, week, month, year }

const _monthNames = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// "Buchungen"-Tab: nach Zeitraum (Tag/Woche/Monat/Jahr) mit ◀▶, Summen und
/// nach Datum gruppierter Liste. Plus Suche + globaler "+".
class AllTransactionsScreen extends ConsumerStatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  ConsumerState<AllTransactionsScreen> createState() =>
      _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends ConsumerState<AllTransactionsScreen> {
  final _query = TextEditingController();
  _PeriodView _view = _PeriodView.month;
  DateTime _anchor = DateTime.now();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _range() {
    final a = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_view) {
      case _PeriodView.day:
        return (a, a.add(const Duration(days: 1)));
      case _PeriodView.week:
        final start = a.subtract(Duration(days: a.weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case _PeriodView.month:
        return (DateTime(a.year, a.month, 1), DateTime(a.year, a.month + 1, 1));
      case _PeriodView.year:
        return (DateTime(a.year, 1, 1), DateTime(a.year + 1, 1, 1));
    }
  }

  void _shift(int dir) {
    setState(() {
      switch (_view) {
        case _PeriodView.day:
          _anchor = _anchor.add(Duration(days: dir));
        case _PeriodView.week:
          _anchor = _anchor.add(Duration(days: 7 * dir));
        case _PeriodView.month:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
        case _PeriodView.year:
          _anchor = DateTime(_anchor.year + dir, 1, 1);
      }
    });
  }

  String _label() {
    final (s, e) = _range();
    final df = DateFormat('dd.MM.yyyy');
    switch (_view) {
      case _PeriodView.day:
        return df.format(s);
      case _PeriodView.week:
        final endIncl = e.subtract(const Duration(days: 1));
        return '${DateFormat('dd.MM.').format(s)} – ${df.format(endIncl)}';
      case _PeriodView.month:
        return '${_monthNames[s.month - 1]} ${s.year}';
      case _PeriodView.year:
        return '${s.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(allTransactionsProvider).asData?.value ??
        const <AppTransaction>[];
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);

    final (start, end) = _range();
    final q = _query.text.trim().toLowerCase();

    final filtered = txs.where((t) {
      if (t.occurredOn.isBefore(start) || !t.occurredOn.isBefore(end)) {
        return false;
      }
      if (q.isEmpty) return true;
      final cat = t.categoryId == null ? '' : (catNames[t.categoryId] ?? '');
      final acc = accountNames[t.accountId] ?? '';
      return t.title.toLowerCase().contains(q) ||
          t.note.toLowerCase().contains(q) ||
          cat.toLowerCase().contains(q) ||
          acc.toLowerCase().contains(q);
    }).toList();

    var income = 0;
    var expense = 0;
    for (final t in filtered) {
      if (t.type == TransactionType.income) income += t.amountCents;
      if (t.type == TransactionType.expense) expense += t.amountCents;
    }

    // nach Tag gruppieren
    final byDay = <DateTime, List<AppTransaction>>{};
    for (final t in filtered) {
      final d = DateTime(t.occurredOn.year, t.occurredOn.month, t.occurredOn.day);
      byDay.putIfAbsent(d, () => []).add(t);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<_PeriodView>(
              segments: const [
                ButtonSegment(value: _PeriodView.day, label: Text('Tag')),
                ButtonSegment(value: _PeriodView.week, label: Text('Woche')),
                ButtonSegment(value: _PeriodView.month, label: Text('Monat')),
                ButtonSegment(value: _PeriodView.year, label: Text('Jahr')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(_label(),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              IconButton(
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _SumBox(label: 'Einnahmen', cents: income, color: Colors.green.shade700),
                const SizedBox(width: 8),
                _SumBox(label: 'Ausgaben', cents: expense, color: Colors.red.shade700),
                const SizedBox(width: 8),
                _SumBox(
                  label: 'Saldo',
                  cents: income - expense,
                  color: (income - expense) >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Suchen …',
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
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allTransactionsProvider);
                ref.invalidate(accountsProvider);
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: filtered.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Keine Buchungen in diesem Zeitraum.')),
                      ],
                    )
                  : ListView.builder(
                      itemCount: days.length,
                      itemBuilder: (_, i) {
                        final day = days[i];
                        final items = byDay[day]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                DateFormat('EEEE, dd.MM.yyyy', 'de')
                                    .formatSafe(day),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            for (final t in items)
                              _TxTile(
                                tx: t,
                                accountName: accountNames[t.accountId] ?? '',
                                categoryName: t.categoryId == null
                                    ? null
                                    : catNames[t.categoryId],
                                onTap: () =>
                                    context.go('/transactions/${t.id}'),
                              ),
                            const Divider(height: 1),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sichere Datumsformatierung ohne geladene Locale-Daten (Fallback dd.MM.yyyy).
extension on DateFormat {
  String formatSafe(DateTime d) {
    try {
      return format(d);
    } catch (_) {
      return DateFormat('dd.MM.yyyy').format(d);
    }
  }
}

class _SumBox extends StatelessWidget {
  const _SumBox({required this.label, required this.cents, required this.color});

  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(
                  formatCents(cents),
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.tx,
    required this.accountName,
    required this.categoryName,
    required this.onTap,
  });

  final AppTransaction tx;
  final String accountName;
  final String? categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final income = tx.type == TransactionType.income;
    final transfer = tx.type == TransactionType.transfer;
    final color = transfer
        ? null
        : (income ? Colors.green.shade700 : Colors.red.shade700);
    final sub = [
      if (accountName.isNotEmpty) accountName,
      ?categoryName,
    ].join('  ·  ');
    final amountText = switch (tx.type) {
      TransactionType.income => '+${formatCents(tx.amountCents)}',
      TransactionType.expense => '-${formatCents(tx.amountCents)}',
      TransactionType.transfer => formatCents(tx.amountCents),
    };
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(
        transfer
            ? Icons.swap_horiz
            : (income ? Icons.south_west : Icons.north_east),
        color: color,
      ),
      title: Text(tx.title.isEmpty
          ? (categoryName ?? tx.type.label)
          : tx.title),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tx.receiptPath != null)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.attach_file, size: 16),
            ),
          Text(amountText,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
