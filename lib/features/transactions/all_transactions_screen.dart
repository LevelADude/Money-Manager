import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/bento.dart';
import '../../shared/category_icons.dart';
import '../../shared/data_refresh.dart';
import '../../shared/hide_amounts_toggle.dart';
import '../../shared/money.dart';
import '../../shared/money_text.dart';
import '../../shared/responsive.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../currency/currency_providers.dart';
// Deferred — siehe Begruendung in export_screen.dart: haelt `pdf`/`printing`
// aus dem Start-Bundle heraus, geladen wird erst beim PDF-Export.
import '../export/pdf_export.dart' deferred as pdf_export;
import '../profile/profile_switcher.dart';
import '../settings/settings_providers.dart';
import 'person_filter.dart';
import 'transaction_providers.dart';
import '../../core/theme.dart';

enum _PeriodView { day, week, month, year }

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
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');
    final sorted = [...items]
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));
    final rows = [
      for (final t in sorted)
        [
          df.format(t.occurredOn),
          l.transactionType(t.type),
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
      await pdf_export.loadLibrary();
      await pdf_export.shareTransactionsPdf(
        heading: l.pdfHeading,
        periodLabel: '${_label()} · ${l.txCount(items.length)}',
        rows: rows,
        incomeText: formatCents(income),
        expenseText: formatCents(expense),
        balanceText: formatCents(income - expense),
        headers: [
          l.dateLabel,
          l.pdfColType,
          l.accountLabel,
          l.category,
          l.fieldTitle,
          l.amount,
        ],
        emptyText: l.noTransactionsPeriod,
        incomeLabel: l.income,
        expenseLabel: l.expenses,
        balanceLabel: l.balance,
        pageLabel: l.pdfPageOf,
        filename: 'money-manager-${_view.name}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.pdfError(e))));
      }
    }
  }

  String _label() {
    final l = AppLocalizations.of(context);
    final (s, e) = _range();
    final df = DateFormat('dd.MM.yyyy');
    switch (_view) {
      case _PeriodView.day:
        return df.format(s);
      case _PeriodView.week:
        final endIncl = e.subtract(const Duration(days: 1));
        return '${DateFormat('dd.MM.').format(s)} – ${df.format(endIncl)}';
      case _PeriodView.month:
        return '${l.monthName(s.month)} ${s.year}';
      case _PeriodView.year:
        return '${s.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(personFilteredTransactionsProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final catNames = ref.watch(categoryNamesProvider);
    // Für das Emoji im Kreis; dieselbe Quelle wie die Namen (kein Extra-Abruf).
    final categories = {
      for (final c
          in ref.watch(categoriesRawProvider).value ?? const <Category>[])
        c.id: c,
    };
    final allTags = ref.watch(allTagsProvider);
    final splitTxIds = ref.watch(splitsByTransactionProvider).keys.toSet();
    final convert = ref.watch(converterProvider);
    final baseCur = ref.watch(settingsProvider.select((s) => s.baseCurrency));
    final curOf = {for (final a in accounts) a.id: a.currency};
    // Tag-Filter aufräumen, falls der Tag nicht mehr existiert.
    if (_tagFilter != null && !allTags.contains(_tagFilter)) {
      _tagFilter = null;
    }

    final l = AppLocalizations.of(context);
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

    // Summen und Gruppierung nach Tag in einem Durchlauf.
    var income = 0;
    var expense = 0;
    final byDay = <DateTime, List<AppTransaction>>{};
    final dayNet = <DateTime, int>{};
    for (final t in filtered) {
      final a = convert(t.amountCents, curOf[t.accountId] ?? baseCur);
      final d = DateTime(
        t.occurredOn.year,
        t.occurredOn.month,
        t.occurredOn.day,
      );
      byDay.putIfAbsent(d, () => []).add(t);
      if (t.type == TransactionType.income) {
        income += a;
        dayNet[d] = (dayNet[d] ?? 0) + a;
      } else if (t.type == TransactionType.expense) {
        expense += a;
        dayNet[d] = (dayNet[d] ?? 0) - a;
      }
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    final colors = AppColors.of(context);
    final wide = context.isWide;
    final pillBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: colors.hairline),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navTransactions),
        actions: [
          const HideAmountsToggle(),
          const ProfileSwitcher(),
          IconButton(
            tooltip: l.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => refreshAllData(ref),
          ),
          IconButton(
            tooltip: l.today,
            icon: const Icon(Icons.today_outlined),
            onPressed: () => setState(() => _anchor = DateTime.now()),
          ),
          IconButton(
            tooltip: l.periodAsPdf,
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
      // Neue Buchung: Plus-Knopf der Navigation (MainScaffold).
      body: Column(
        children: [
          // Bedienelemente bleiben stehen, Kacheln und Liste scrollen.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Bento.margin,
              4,
              Bento.margin,
              0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_PeriodView>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _PeriodView.day,
                    label: Text(l.periodDay),
                  ),
                  ButtonSegment(
                    value: _PeriodView.week,
                    label: Text(l.periodWeek),
                  ),
                  ButtonSegment(
                    value: _PeriodView.month,
                    label: Text(l.periodMonth),
                  ),
                  ButtonSegment(
                    value: _PeriodView.year,
                    label: Text(l.periodYear),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _label(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                refreshAllData(ref);
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Bento.margin,
                      4,
                      Bento.margin,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: BentoGrid(
                        cells: [
                          BentoCell(
                            child: BentoStat(
                              label: l.income,
                              value: MoneyText(
                                income,
                                style: TextStyle(color: colors.income),
                              ),
                            ),
                          ),
                          BentoCell(
                            child: BentoStat(
                              label: l.expenses,
                              value: MoneyText(expense),
                            ),
                          ),
                          BentoCell(
                            span: 2,
                            child: BentoStat(
                              label: l.balance,
                              value: MoneyText(
                                income - expense,
                                prefix: income - expense > 0 ? '+' : '',
                                style: TextStyle(
                                  color: income - expense < 0
                                      ? colors.expense
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Bento.margin,
                      Bento.gap,
                      Bento.margin,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: TextField(
                        controller: _query,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: l.searchHint,
                          prefixIcon: const Icon(Icons.search),
                          border: pillBorder,
                          enabledBorder: pillBorder,
                          suffixIcon: _query.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _query.clear()),
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (allTags.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(
                            Bento.margin,
                            8,
                            Bento.margin,
                            0,
                          ),
                          children: [
                            for (final tag in allTags)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(tag),
                                  selected: _tagFilter == tag,
                                  onSelected: (sel) => setState(
                                    () => _tagFilter = sel ? tag : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (filtered.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 64),
                      sliver: SliverToBoxAdapter(
                        child: Center(child: Text(l.noTransactionsPeriod)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Bento.margin,
                        18,
                        Bento.margin,
                        0,
                      ).withBarInset(context),
                      // Ein Tag = ein Listeneintrag; Tage werden erst beim
                      // Scrollen gebaut.
                      sliver: SliverList.builder(
                        itemCount: days.length,
                        itemBuilder: (_, i) {
                          final day = days[i];
                          final items = byDay[day]!;
                          final net = dayNet[day];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                BentoSectionHeader(
                                  label: l.dayHeader(day),
                                  trailing: net == null
                                      ? null
                                      : MoneyText(
                                          net,
                                          prefix: net > 0 ? '+' : '',
                                        ),
                                ),
                                BentoList(
                                  children: [
                                    for (final t in items)
                                      _TxTile(
                                        tx: t,
                                        accountName:
                                            accountNames[t.accountId] ?? '',
                                        category: categories[t.categoryId],
                                        categoryName: t.categoryId == null
                                            ? null
                                            : catNames[t.categoryId],
                                        currency: curOf[t.accountId] ?? baseCur,
                                        hasSplit: splitTxIds.contains(t.id),
                                        wide: wide,
                                        onTap: () =>
                                            context.go('/transactions/${t.id}'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.tx,
    required this.accountName,
    required this.category,
    required this.categoryName,
    required this.onTap,
    required this.currency,
    required this.wide,
    this.hasSplit = false,
  });

  final AppTransaction tx;
  final String accountName;
  final Category? category;
  final String? categoryName;
  final VoidCallback onTap;
  final String currency;

  /// Breit: Kategorie und Konto als eigene Spalten statt in der Unterzeile.
  final bool wide;
  final bool hasSplit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ink2 = Theme.of(context).colorScheme.onSurfaceVariant;
    final income = tx.type == TransactionType.income;
    final transfer = tx.type == TransactionType.transfer;
    final extras = [if (hasSplit) l.splitLabel, for (final t in tx.tags) '#$t'];
    final sub = [
      if (!wide) ?categoryName,
      if (!wide && accountName.isNotEmpty) accountName,
      ...extras,
    ].join('  ·  ');
    final prefix = switch (tx.type) {
      TransactionType.income => '+',
      TransactionType.expense => '-',
      TransactionType.transfer => '',
    };
    return BentoRow(
      onTap: onTap,
      leading: BentoGlyph(
        child: transfer
            ? const Icon(Icons.swap_horiz)
            : category != null
            ? categoryGlyph(category!, size: 22, color: ink2)
            : Icon(income ? Icons.south_west : Icons.north_east),
      ),
      title: Text(
        tx.title.isEmpty
            ? (categoryName ?? l.transactionType(tx.type))
            : tx.title,
      ),
      subtitle: sub.isEmpty ? null : Text(sub),
      columns: wide ? [Text(categoryName ?? ''), Text(accountName)] : const [],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSplit)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.call_split, size: 16, color: ink2),
            ),
          if (tx.receiptPath != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.attach_file, size: 16, color: ink2),
            ),
          MoneyText(
            tx.amountCents,
            prefix: prefix,
            currency: currency,
            style: TextStyle(
              color: income ? AppColors.of(context).income : null,
            ),
          ),
        ],
      ),
    );
  }
}
