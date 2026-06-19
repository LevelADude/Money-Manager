import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../shared/data_refresh.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../currency/currency_providers.dart';
import '../export/pdf_export.dart';
import '../profile/profile_providers.dart';
import '../profile/profile_switcher.dart';
import '../settings/settings_providers.dart';
import '../sharing/access_grant_providers.dart';
import 'person_filter.dart';
import 'transaction_providers.dart';

enum _PeriodView { day, week, month, year }

const _monthNames = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

const _weekdayNames = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
  'Freitag', 'Samstag', 'Sonntag',
];

/// Deutscher Datums-Header ohne intl-Locale-Daten (die nicht initialisiert
/// sind) – z. B. "Montag, 18.06.2026".
String _germanDate(DateTime d) {
  final wd = _weekdayNames[d.weekday - 1]; // weekday: 1=Mo … 7=So
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$wd, $dd.$mm.${d.year}';
}

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
  String? _tagFilter;

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

  Future<void> _sharePeriodPdf({
    required List<AppTransaction> items,
    required Map<String, String> accountNames,
    required Map<String, String> catNames,
    required int income,
    required int expense,
  }) async {
    final df = DateFormat('dd.MM.yyyy');
    final sorted = [...items]
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));
    final rows = [
      for (final t in sorted)
        [
          df.format(t.occurredOn),
          t.type.label,
          accountNames[t.accountId] ?? '',
          t.categoryId == null ? '' : (catNames[t.categoryId] ?? ''),
          t.title,
          switch (t.type) {
            TransactionType.income => '+${formatCents(t.amountCents)}',
            TransactionType.expense => '-${formatCents(t.amountCents)}',
            TransactionType.transfer => formatCents(t.amountCents),
          },
        ],
    ];
    try {
      await shareTransactionsPdf(
        heading: 'Money Manager – Buchungen',
        periodLabel: '${_label()} · ${items.length} Buchungen',
        rows: rows,
        incomeText: formatCents(income),
        expenseText: formatCents(expense),
        balanceText: formatCents(income - expense),
        filename: 'money-manager-${_view.name}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF-Fehler: $e')));
      }
    }
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
    final txs = ref.watch(personFilteredTransactionsProvider);
    final personFilter = ref.watch(personFilterProvider);
    final manageableOwners = ref.watch(manageableOwnersProvider);
    // Buchen nur in der Gesamtansicht oder bei Personen, die man verwalten darf.
    final canAdd =
        personFilter == null || manageableOwners.contains(personFilter);
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);
    final allTags = ref.watch(allTagsProvider);
    final splitTxIds = ref.watch(splitsByTransactionProvider).keys.toSet();
    final readOnly = ref.watch(isReadOnlyProvider).asData?.value ?? false;
    final convert = ref.watch(converterProvider);
    final baseCur = ref.watch(settingsProvider.select((s) => s.baseCurrency));
    final curOf = {for (final a in accounts) a.id: a.currency};
    // Tag-Filter aufräumen, falls der Tag nicht mehr existiert.
    if (_tagFilter != null && !allTags.contains(_tagFilter)) {
      _tagFilter = null;
    }

    final (start, end) = _range();
    final q = _query.text.trim().toLowerCase();

    final filtered = txs.where((t) {
      if (t.occurredOn.isBefore(start) || !t.occurredOn.isBefore(end)) {
        return false;
      }
      if (_tagFilter != null &&
          !t.tags.any((x) => x.toLowerCase() == _tagFilter!.toLowerCase())) {
        return false;
      }
      if (q.isEmpty) return true;
      final cat = t.categoryId == null ? '' : (catNames[t.categoryId] ?? '');
      final acc = accountNames[t.accountId] ?? '';
      return t.title.toLowerCase().contains(q) ||
          t.note.toLowerCase().contains(q) ||
          cat.toLowerCase().contains(q) ||
          acc.toLowerCase().contains(q) ||
          t.tags.any((x) => x.toLowerCase().contains(q));
    }).toList();

    var income = 0;
    var expense = 0;
    for (final t in filtered) {
      final a = convert(t.amountCents, curOf[t.accountId] ?? baseCur);
      if (t.type == TransactionType.income) income += a;
      if (t.type == TransactionType.expense) expense += a;
    }

    // nach Tag gruppieren
    final byDay = <DateTime, List<AppTransaction>>{};
    for (final t in filtered) {
      final d = DateTime(t.occurredOn.year, t.occurredOn.month, t.occurredOn.day);
      byDay.putIfAbsent(d, () => []).add(t);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buchungen'),
        actions: [
          const ProfileSwitcher(),
          IconButton(
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh),
            onPressed: () => refreshAllData(ref),
          ),
          IconButton(
            tooltip: 'Heute',
            icon: const Icon(Icons.today_outlined),
            onPressed: () => setState(() => _anchor = DateTime.now()),
          ),
          IconButton(
            tooltip: 'Zeitraum als PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: filtered.isEmpty
                ? null
                : () => _sharePeriodPdf(
                      items: filtered,
                      accountNames: accountNames,
                      catNames: catNames,
                      income: income,
                      expense: expense,
                    ),
          ),
        ],
      ),
      floatingActionButton: (readOnly || !canAdd)
          ? null
          : FloatingActionButton.extended(
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
          if (allTags.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final tag in allTags)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(tag),
                        selected: _tagFilter == tag,
                        onSelected: (sel) =>
                            setState(() => _tagFilter = sel ? tag : null),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                refreshAllData(ref);
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
                                _germanDate(day),
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
                                currency: curOf[t.accountId] ?? baseCur,
                                hasSplit: splitTxIds.contains(t.id),
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
    required this.currency,
    this.hasSplit = false,
  });

  final AppTransaction tx;
  final String accountName;
  final String? categoryName;
  final VoidCallback onTap;
  final String currency;
  final bool hasSplit;

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
      if (hasSplit) 'Aufgeteilt',
      for (final t in tx.tags) '#$t',
    ].join('  ·  ');
    final prefix = switch (tx.type) {
      TransactionType.income => '+',
      TransactionType.expense => '-',
      TransactionType.transfer => '',
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
          if (hasSplit)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.call_split, size: 16),
            ),
          if (tx.receiptPath != null)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.attach_file, size: 16),
            ),
          MoneyText(tx.amountCents,
              prefix: prefix,
              currency: currency,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
