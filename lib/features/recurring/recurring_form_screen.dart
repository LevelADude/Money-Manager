import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../../data/models/recurring_rule.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/calculator_sheet.dart';
import '../../shared/money.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import 'recurring_providers.dart';

/// Dauerauftrag anlegen oder bearbeiten.
class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.ruleId});

  final String? ruleId;

  bool get isEditing => ruleId != null;

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _count = TextEditingController(text: '1');
  String? _accountId;
  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _transferTargetId;
  IntervalUnit _unit = IntervalUnit.month;
  DateTime _nextDue = DateTime.now();
  DateTime? _endDate;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    _count.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_prefilled || !widget.isEditing) return;
    final rules = ref.read(recurringRulesProvider).asData?.value ?? const [];
    for (final r in rules) {
      if (r.id == widget.ruleId) {
        _amount.text = centsToInput(r.amountCents);
        _title.text = r.title;
        _note.text = r.note;
        _count.text = r.intervalCount.toString();
        _accountId = r.accountId;
        _type = r.type;
        _categoryId = r.categoryId;
        _transferTargetId = r.transferAccountId;
        _unit = r.intervalUnit;
        _nextDue = r.nextDue;
        _endDate = r.endDate;
        _prefilled = true;
        break;
      }
    }
  }

  Future<void> _pickNextDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDue,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _nextDue = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _nextDue,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = parseToCents(_amount.text);
    final count = int.tryParse(_count.text.trim()) ?? 1;
    if (cents == null || cents <= 0 || _accountId == null) return;
    if (_type == TransactionType.transfer && _transferTargetId == null) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.chooseTargetAccount)),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(recurringRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repo.updateRule(
          id: widget.ruleId!,
          accountId: _accountId!,
          type: _type,
          amountCents: cents,
          categoryId: _categoryId,
          transferAccountId: _transferTargetId,
          title: _title.text.trim(),
          note: _note.text.trim(),
          intervalUnit: _unit,
          intervalCount: count < 1 ? 1 : count,
          nextDue: _nextDue,
          endDate: _endDate,
          active: true,
        );
      } else {
        await repo.createRule(
          accountId: _accountId!,
          type: _type,
          amountCents: cents,
          categoryId: _categoryId,
          transferAccountId: _transferTargetId,
          title: _title.text.trim(),
          note: _note.text.trim(),
          intervalUnit: _unit,
          intervalCount: count < 1 ? 1 : count,
          nextDue: _nextDue,
          endDate: _endDate,
        );
      }
      if (mounted) context.go('/more/recurring');
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorWith(e))));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteRecurringTitle),
        content: Text(l.deleteRecurringBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(recurringRepositoryProvider).deleteRule(widget.ruleId!);
    if (mounted) context.go('/recurring');
  }

  @override
  Widget build(BuildContext context) {
    _prefill();
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');
    final isTransfer = _type == TransactionType.transfer;
    final accounts = (ref.watch(accountsProvider).asData?.value ??
            const <Account>[])
        .where((a) => !a.archived)
        .toList();
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;

    final categories = (ref.watch(categoriesProvider).asData?.value ??
            const <Category>[])
        .where((c) => c.active && c.matches(_type))
        .toList();
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }
    final targets =
        accounts.where((a) => a.id != _accountId).toList();
    if (_transferTargetId != null &&
        !targets.any((a) => a.id == _transferTargetId)) {
      _transferTargetId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l.editRecurring : l.newRecurring),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
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
                    SegmentedButton<TransactionType>(
                      segments: [
                        ButtonSegment(
                            value: TransactionType.expense,
                            label: Text(l.transactionType(TransactionType.expense))),
                        ButtonSegment(
                            value: TransactionType.income,
                            label: Text(l.transactionType(TransactionType.income))),
                        ButtonSegment(
                            value: TransactionType.transfer,
                            label: Text(l.transactionType(TransactionType.transfer))),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) =>
                          setState(() => _type = s.first),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      decoration: InputDecoration(
                        labelText: l.accountLabel,
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: [
                        for (final a in accounts)
                          DropdownMenuItem(value: a.id, child: Text(a.name)),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: l.amountCalcShort,
                        prefixIcon: const Icon(Icons.euro),
                        suffixIcon: IconButton(
                          tooltip: l.calculator,
                          icon: const Icon(Icons.calculate_outlined),
                          onPressed: () async {
                            final r = await showCalculatorSheet(context,
                                initial: _amount.text);
                            if (r != null) setState(() => _amount.text = r);
                          },
                        ),
                      ),
                      validator: (v) {
                        final c = parseToCents(v ?? '');
                        if (c == null || c <= 0) {
                          return l.enterValidAmount;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (isTransfer)
                      DropdownButtonFormField<String?>(
                        initialValue: _transferTargetId,
                        decoration: InputDecoration(
                          labelText: l.targetAccount,
                          prefixIcon: const Icon(Icons.swap_horiz),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                              value: null, child: Text(l.chooseDash)),
                          for (final a in targets)
                            DropdownMenuItem<String?>(
                                value: a.id, child: Text(a.name)),
                        ],
                        onChanged: (v) =>
                            setState(() => _transferTargetId = v),
                      )
                    else
                      DropdownButtonFormField<String?>(
                        initialValue: _categoryId,
                        decoration: InputDecoration(
                          labelText: l.category,
                          prefixIcon: const Icon(Icons.label_outline),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                              value: null, child: Text(l.noCategoryOption)),
                          for (final c in categories)
                            DropdownMenuItem<String?>(
                                value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l.recurringTitleHint,
                        prefixIcon: const Icon(Icons.storefront_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(l.everyWord),
                        SizedBox(
                          width: 64,
                          child: TextFormField(
                            controller: _count,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<IntervalUnit>(
                            initialValue: _unit,
                            items: [
                              for (final u in IntervalUnit.values)
                                DropdownMenuItem(
                                    value: u, child: Text(l.intervalUnitLabel(u))),
                            ],
                            onChanged: (v) => setState(
                                () => _unit = v ?? IntervalUnit.month),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: Text(l.nextDueLabel),
                      subtitle: Text(df.format(_nextDue)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: _pickNextDue,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_busy),
                      title: Text(l.endDateOptional),
                      subtitle: Text(
                          _endDate == null ? l.noEnd : df.format(_endDate!)),
                      trailing: _endDate == null
                          ? const Icon(Icons.edit_calendar)
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _endDate = null),
                            ),
                      onTap: _pickEndDate,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
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
