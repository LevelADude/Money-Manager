import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/models/reservation.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import '../transactions/transaction_providers.dart';
import 'reservation_providers.dart';

/// Öffnet das „Einlösen"-Sheet: aus der Reservierung wird eine Ausgabe auf
/// demselben Konto (Betrag/Name/Kategorie vorbelegt, anpassbar). Liefert
/// `true`, wenn eingelöst wurde.
Future<bool> showRedeemReservationSheet(
  BuildContext context,
  Reservation reservation,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RedeemSheet(reservation: reservation),
  );
  return result == true;
}

class _RedeemSheet extends ConsumerStatefulWidget {
  const _RedeemSheet({required this.reservation});

  final Reservation reservation;

  @override
  ConsumerState<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends ConsumerState<_RedeemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late String? _categoryId;
  late DateTime _date;
  late DateTime? _dueOn;
  bool _keepRest = true;
  bool _saving = false;

  Reservation get r => widget.reservation;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: r.amountCents > 0 ? centsToInput(r.amountCents) : '',
    );
    _title = TextEditingController(text: r.name);
    _categoryId = r.categoryId;
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    // Wiederkehrende Rücklage mit erreichter Fälligkeit: nächster Termin ein
    // Jahr später vorschlagen (typisch: jährliche Zahlung). Anpassbar.
    final due = r.dueOn;
    _dueOn = (r.isRecurring && due != null && !due.isAfter(_date))
        ? advanceDate(due, IntervalUnit.year, 1)
        : due;
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  int get _cents => parseToCents(_amount.text) ?? 0;
  int get _rest => (r.amountCents - _cents).clamp(0, r.amountCents);

  /// Reservierung bleibt nach dem Einlösen bestehen?
  bool get _staysOpen => r.isRecurring || (_keepRest && _rest > 0);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(reservationRepositoryProvider)
          .redeem(
            id: r.id,
            amountCents: _cents,
            occurredOn: _date,
            title: _title.text.trim(),
            categoryId: _categoryId,
            note: r.note,
            keepRest: _keepRest,
            dueOn: _staysOpen ? _dueOn : null,
          );
      ref.invalidate(allTransactionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.redeemed)));
        Navigator.pop(context, true);
      }
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
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final currency =
        accounts.where((a) => a.id == r.accountId).firstOrNull?.currency ??
        gBaseCurrency;
    final allCats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final categories = allCats
        .where(
          (c) =>
              (c.active && c.matches(TransactionType.expense)) ||
              c.id == _categoryId,
        )
        .toList();
    if (_categoryId != null &&
        allCats.isNotEmpty &&
        !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }
    final partial = _cents > 0 && _cents < r.amountCents;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.redeemTitle(r.name),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                l.redeemExplain,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.redeemAmountLabel,
                  suffixText: currencySymbol(currency),
                  helperText: partial
                      ? l.restAmount(formatMoney(_rest, currency))
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final c = parseToCents(v ?? '');
                  if (c == null || c <= 0) return l.enterValidAmount;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.name),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: InputDecoration(labelText: l.category),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(l.dateLabel),
                subtitle: Text(df.format(_date)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              if (partial)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.keepRestReserved),
                  subtitle: Text(formatMoney(_rest, currency)),
                  value: _keepRest,
                  onChanged: (v) => setState(() => _keepRest = v),
                ),
              if (_staysOpen && r.dueOn != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_repeat),
                  title: Text(l.nextDueOptional),
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
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueOn ?? _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _dueOn = picked);
                  },
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_bag_outlined),
                label: Text(l.redeemAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
