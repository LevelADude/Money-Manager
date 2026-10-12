import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/models/reservation.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/calculator_sheet.dart';
import '../../shared/money.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import 'reservation_providers.dart';

/// Reservierung anlegen oder bearbeiten.
class ReservationFormScreen extends ConsumerStatefulWidget {
  const ReservationFormScreen({super.key, this.accountId, this.reservationId});

  /// Vorbelegtes Konto (aus der Kontodetail-Ansicht).
  final String? accountId;
  final String? reservationId;

  bool get isEditing => reservationId != null;

  @override
  ConsumerState<ReservationFormScreen> createState() =>
      _ReservationFormScreenState();
}

class _ReservationFormScreenState extends ConsumerState<ReservationFormScreen> {
  static const _units = [
    IntervalUnit.week,
    IntervalUnit.month,
    IntervalUnit.year,
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _topup = TextEditingController();
  final _target = TextEditingController();
  String? _accountId;
  String? _categoryId;
  DateTime? _dueOn;
  bool _recurring = false;
  IntervalUnit _unit = IntervalUnit.month;
  late DateTime _topupStart;
  // Zwischenspeicher gegen Leer-Flackern bei kurzem Neuladen.
  List<Account> _accountsCache = const [];
  List<Category> _allCatsCache = const [];
  Reservation? _original;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accountId;
    final now = DateTime.now();
    _topupStart = advanceDate(
      DateTime(now.year, now.month, now.day),
      IntervalUnit.month,
      1,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    _topup.dispose();
    _target.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_prefilled || !widget.isEditing) return;
    for (final r in ref.read(reservationsProvider)) {
      if (r.id != widget.reservationId) continue;
      _original = r;
      _name.text = r.name;
      _amount.text = r.amountCents == 0 ? '' : centsToInput(r.amountCents);
      _note.text = r.note;
      _accountId = r.accountId;
      _categoryId = r.categoryId;
      _dueOn = r.dueOn;
      _recurring = r.isRecurring;
      if (r.isRecurring) {
        _topup.text = centsToInput(r.topupCents!);
        _unit = r.topupUnit!;
        _topupStart = r.topupStart!;
        if (r.targetCents != null) _target.text = centsToInput(r.targetCents!);
      }
      _prefilled = true;
      break;
    }
  }

  void _leave() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        widget.accountId != null
            ? '/account/${widget.accountId}'
            : '/more/reservations',
      );
    }
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  /// Würde die Reservierung das Konto überreservieren?
  bool _wouldOverReserve(String accountId, int amountCents) {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return false;
    final balance = ref.read(accountBalancesProvider)[accountId] ?? 0;
    var reserved = ref.read(reservedByAccountProvider)[accountId] ?? 0;
    // Den bisherigen Betrag dieser Reservierung nicht doppelt zählen.
    final old = _original;
    if (old != null && old.accountId == accountId) reserved -= old.amountCents;
    return isOverReserved(
      balanceCents: balance,
      reservedCents: reserved + amountCents,
      isLiability: account.type.isLiability,
      creditLimitCents: account.creditLimitCents,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final accountId = _accountId;
    if (accountId == null) return;
    final l = AppLocalizations.of(context);
    final cents = _amount.text.trim().isEmpty
        ? 0
        : (parseToCents(_amount.text) ?? 0);
    final topup = _recurring ? parseToCents(_topup.text) : null;
    final parsedTarget = _recurring ? parseToCents(_target.text) : null;
    final target = (parsedTarget ?? 0) > 0 ? parsedTarget : null;

    if (_wouldOverReserve(accountId, cents)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.overReservedShort),
          content: Text(l.overReservedSave),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.saveAnyway),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    // Zählung der Aufstockungen nur neu beginnen, wenn sich der Rhythmus
    // (Einheit/Start) ändert — eine reine Betragsänderung behält sie.
    final old = _original;
    final resetCount =
        old == null ||
        !old.isRecurring ||
        !_recurring ||
        old.topupUnit != _unit ||
        old.topupStart != _topupStart;

    setState(() => _saving = true);
    try {
      await ref
          .read(reservationRepositoryProvider)
          .upsert(
            id: widget.reservationId,
            accountId: accountId,
            name: _name.text.trim(),
            amountCents: cents,
            dueOn: _dueOn,
            categoryId: _categoryId,
            note: _note.text.trim(),
            targetCents: target,
            topupCents: topup,
            topupUnit: _recurring ? _unit : null,
            topupStart: _recurring ? _topupStart : null,
            resetTopupCount: resetCount,
          );
      // Liegt der erste Aufstockungstermin schon zurück, sofort nachziehen.
      if (_recurring) ref.invalidate(reservationTopupProvider);
      _leave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.errorWith(e))));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _prefill();
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');

    if (ref.watch(accountsProvider).hasValue) {
      _accountsCache = ref
          .watch(manageableAccountsProvider)
          .where((a) => !a.archived || a.id == _accountId)
          .toList();
    }
    final accounts = _accountsCache;
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
    final account = accounts.where((a) => a.id == _accountId).firstOrNull;
    final currency = account?.currency ?? gBaseCurrency;

    final catsAsync = ref.watch(categoriesProvider);
    if (catsAsync.hasValue) _allCatsCache = catsAsync.value!;
    final categories = _allCatsCache
        .where(
          (c) =>
              (c.active && c.matches(TransactionType.expense)) ||
              c.id == _categoryId,
        )
        .toList();
    if (_categoryId != null &&
        _allCatsCache.isNotEmpty &&
        !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    Widget currencyPrefix() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        currencySymbol(currency),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );

    Widget amountField(
      TextEditingController c,
      String label, {
      bool allowZero = false,
    }) => TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: currencyPrefix(),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        suffixIcon: IconButton(
          tooltip: l.calculator,
          icon: const Icon(Icons.calculate_outlined),
          onPressed: () async {
            final r = await showCalculatorSheet(context, initial: c.text);
            if (r != null) setState(() => c.text = r);
          },
        ),
      ),
      validator: (v) {
        final text = (v ?? '').trim();
        if (allowZero && text.isEmpty) return null;
        final cents = parseToCents(text);
        if (cents == null || cents < 0 || (!allowZero && cents == 0)) {
          return l.enterValidAmount;
        }
        return null;
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l.editReservation : l.newReservation),
      ),
      body: accounts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.createAccountFirst),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      autofocus: !widget.isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l.reservationName,
                        prefixIcon: const Icon(Icons.bookmark_outline),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? l.reservationNameRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      decoration: InputDecoration(
                        labelText: l.accountLabel,
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet_outlined,
                        ),
                      ),
                      items: [
                        for (final a in accounts)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} (${a.currency})'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    const SizedBox(height: 16),
                    amountField(
                      _amount,
                      _recurring ? l.startAmount : l.amount,
                      allowZero: _recurring,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: Text(l.dueOnOptional),
                      subtitle: Text(
                        _dueOn == null ? l.noDueDate : df.format(_dueOn!),
                      ),
                      trailing: _dueOn == null
                          ? const Icon(Icons.edit_calendar)
                          : IconButton(
                              tooltip: l.delete,
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _dueOn = null),
                            ),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await _pickDate(
                          _dueOn ?? DateTime(now.year, now.month + 1, now.day),
                        );
                        if (picked != null) setState(() => _dueOn = picked);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _categoryId,
                      decoration: InputDecoration(
                        labelText: l.category,
                        helperText: l.reservationCategoryHint,
                        prefixIcon: const Icon(Icons.label_outline),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l.noCategoryOption),
                        ),
                        for (final c in categories)
                          DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(l.categoryName(c)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.autorenew),
                      title: Text(l.recurringReserve),
                      subtitle: Text(l.recurringReserveSub),
                      value: _recurring,
                      onChanged: (v) => setState(() => _recurring = v),
                    ),
                    if (_recurring) ...[
                      const SizedBox(height: 8),
                      amountField(_topup, l.topupAmount),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<IntervalUnit>(
                        initialValue: _unit,
                        decoration: InputDecoration(
                          labelText: l.topupEvery,
                          prefixIcon: const Icon(Icons.repeat),
                        ),
                        items: [
                          for (final u in _units)
                            DropdownMenuItem(
                              value: u,
                              child: Text(l.topupUnitSingular(u)),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _unit = v ?? IntervalUnit.month),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_repeat),
                        title: Text(l.topupStart),
                        subtitle: Text(df.format(_topupStart)),
                        trailing: const Icon(Icons.edit_calendar),
                        onTap: () async {
                          final picked = await _pickDate(_topupStart);
                          if (picked != null) {
                            setState(() => _topupStart = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      amountField(_target, l.targetOptional, allowZero: true),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _note,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l.note,
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(l.save),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
