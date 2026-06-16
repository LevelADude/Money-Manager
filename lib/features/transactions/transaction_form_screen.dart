import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/app_transaction.dart';
import '../../data/models/category.dart';
import '../categories/category_providers.dart';
import 'transaction_providers.dart';

/// Formular zum Erfassen ODER Bearbeiten einer Buchung.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    required this.ledgerId,
    this.transactionId,
  });

  final String ledgerId;

  /// Wenn gesetzt: Bearbeitungsmodus für diese Buchung.
  final String? transactionId;

  bool get isEditing => transactionId != null;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  TransactionDirection _direction = TransactionDirection.expense;
  DateTime _date = DateTime.now();
  String? _categoryId;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _prefillFromExisting() {
    if (_prefilled || !widget.isEditing) return;
    final list = ref.read(transactionsProvider(widget.ledgerId)).asData?.value;
    if (list == null) return;
    for (final t in list) {
      if (t.id == widget.transactionId) {
        _amount.text = t.amount.toStringAsFixed(2).replaceAll('.', ',');
        _note.text = t.note;
        _direction = t.direction;
        _date = t.occurredOn;
        _categoryId = t.categoryId;
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
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null) return;
    setState(() => _saving = true);
    final repo = ref.read(transactionRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repo.updateTransaction(
          id: widget.transactionId!,
          direction: _direction,
          amount: amount,
          occurredOn: _date,
          note: _note.text.trim(),
          categoryId: _categoryId,
        );
      } else {
        await repo.addTransaction(
          ledgerId: widget.ledgerId,
          direction: _direction,
          amount: amount,
          occurredOn: _date,
          note: _note.text.trim(),
          categoryId: _categoryId,
        );
      }
      if (mounted) context.go('/ledger/${widget.ledgerId}');
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
    if (mounted) context.go('/ledger/${widget.ledgerId}');
  }

  @override
  Widget build(BuildContext context) {
    _prefillFromExisting();
    final df = DateFormat('dd.MM.yyyy');
    final all = ref.watch(categoriesProvider(widget.ledgerId)).asData?.value ??
        const <Category>[];
    final categories = all.where((c) => c.matches(_direction)).toList();
    // Gewählte Kategorie passt nicht (mehr) zur Richtung -> zurücksetzen.
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
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
              SegmentedButton<TransactionDirection>(
                segments: const [
                  ButtonSegment(
                    value: TransactionDirection.expense,
                    label: Text('Ausgabe'),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: TransactionDirection.income,
                    label: Text('Einnahme'),
                    icon: Icon(Icons.south_west),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (s) => setState(() => _direction = s.first),
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
                  final parsed =
                      double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return 'Gültigen Betrag eingeben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
                    DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Notiz (optional)',
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
