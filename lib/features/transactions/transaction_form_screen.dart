import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../../shared/money.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import 'transaction_providers.dart';

/// Buchung erfassen ODER bearbeiten (Ausgabe / Einnahme / Übertrag).
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    required this.accountId,
    this.transactionId,
  });

  final String accountId;
  final String? transactionId;

  bool get isEditing => transactionId != null;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _note = TextEditingController();
  late String _sourceAccountId = widget.accountId;
  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  String? _categoryId;
  String? _transferTargetId;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_prefilled || !widget.isEditing) return;
    final txs = ref.read(allTransactionsProvider).asData?.value ?? const [];
    for (final t in txs) {
      if (t.id == widget.transactionId) {
        _amount.text = centsToInput(t.amountCents);
        _title.text = t.title;
        _note.text = t.note;
        _type = t.type;
        _date = t.occurredOn;
        _categoryId = t.categoryId;
        _transferTargetId = t.transferAccountId;
        _sourceAccountId = t.accountId;
        _prefilled = true;
        break;
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = parseToCents(_amount.text);
    if (cents == null || cents <= 0) return;
    if (_type == TransactionType.transfer && _transferTargetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte ein Zielkonto wählen.')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(transactionRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repo.updateTransaction(
          id: widget.transactionId!,
          accountId: _sourceAccountId,
          type: _type,
          amountCents: cents,
          occurredOn: _date,
          title: _title.text.trim(),
          note: _note.text.trim(),
          categoryId: _categoryId,
          transferAccountId: _transferTargetId,
        );
      } else {
        await repo.addTransaction(
          accountId: _sourceAccountId,
          type: _type,
          amountCents: cents,
          occurredOn: _date,
          title: _title.text.trim(),
          note: _note.text.trim(),
          categoryId: _categoryId,
          transferAccountId: _transferTargetId,
        );
      }
      if (mounted) context.go('/account/${widget.accountId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buchung löschen?'),
        content: const Text('Das kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(transactionRepositoryProvider)
        .deleteTransaction(widget.transactionId!);
    if (mounted) context.go('/account/${widget.accountId}');
  }

  @override
  Widget build(BuildContext context) {
    _prefill();
    final df = DateFormat('dd.MM.yyyy');
    final isTransfer = _type == TransactionType.transfer;

    final categories = (ref.watch(categoriesProvider).asData?.value ??
            const <Category>[])
        .where((c) => c.active && c.matches(_type))
        .toList();
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    final targets = (ref.watch(accountsProvider).asData?.value ??
            const <Account>[])
        .where((a) => a.id != _sourceAccountId && !a.archived)
        .toList();
    if (_transferTargetId != null &&
        !targets.any((a) => a.id == _transferTargetId)) {
      _transferTargetId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Buchung bearbeiten' : 'Neue Buchung'),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Ausgabe'),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Einnahme'),
                    icon: Icon(Icons.south_west),
                  ),
                  ButtonSegment(
                    value: TransactionType.transfer,
                    label: Text('Übertrag'),
                    icon: Icon(Icons.swap_horiz),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: !widget.isEditing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Betrag',
                  prefixIcon: Icon(Icons.euro),
                ),
                validator: (v) {
                  final c = parseToCents(v ?? '');
                  if (c == null || c <= 0) return 'Gültigen Betrag eingeben';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (isTransfer)
                DropdownButtonFormField<String?>(
                  initialValue: _transferTargetId,
                  decoration: const InputDecoration(
                    labelText: 'Zielkonto',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— wählen —'),
                    ),
                    for (final a in targets)
                      DropdownMenuItem<String?>(
                          value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _transferTargetId = v),
                )
              else
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Kategorie',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Keine Kategorie'),
                    ),
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
                decoration: const InputDecoration(
                  labelText: 'Titel (z. B. Aldi, Rewe, Aral)',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Notiz',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                leading: const Icon(Icons.calendar_today),
                title: const Text('Datum'),
                subtitle: Text(df.format(_date)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _pickDate,
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
                label: const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
