import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../../shared/money.dart';
import 'account_providers.dart';

/// Konto anlegen oder bearbeiten.
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.accountId});

  final String? accountId;

  bool get isEditing => accountId != null;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _opening = TextEditingController(text: '0,00');
  final _creditLimit = TextEditingController();
  AccountType _type = AccountType.bank;
  bool _includeInNetWorth = true;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _creditLimit.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_prefilled || !widget.isEditing) return;
    final accounts = ref.read(accountsProvider).asData?.value ?? const [];
    for (final a in accounts) {
      if (a.id == widget.accountId) {
        _name.text = a.name;
        _type = a.type;
        _opening.text = centsToInput(a.openingBalanceCents);
        _creditLimit.text =
            a.creditLimitCents == null ? '' : centsToInput(a.creditLimitCents!);
        _includeInNetWorth = a.includeInNetWorth;
        _prefilled = true;
        break;
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final openingCents = parseToCents(_opening.text) ?? 0;
    final creditCents =
        _creditLimit.text.trim().isEmpty ? null : parseToCents(_creditLimit.text);
    setState(() => _saving = true);
    final repo = ref.read(accountRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repo.updateAccount(
          id: widget.accountId!,
          name: _name.text.trim(),
          type: _type,
          openingBalanceCents: openingCents,
          includeInNetWorth: _includeInNetWorth,
          creditLimitCents: creditCents,
        );
      } else {
        await repo.createAccount(
          name: _name.text.trim(),
          type: _type,
          openingBalanceCents: openingCents,
          includeInNetWorth: _includeInNetWorth,
          creditLimitCents: creditCents,
        );
      }
      ref.invalidate(accountsProvider);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _prefill();
    final isLiability = _type.isLiability;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Konto bearbeiten' : 'Neues Konto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofocus: !widget.isEditing,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name eingeben' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Kontotyp',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final t in AccountType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _type = v ?? AccountType.bank),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _opening,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: 'Anfangssaldo',
                  helperText: isLiability
                      ? 'Bestehende Schuld als negativen Wert eingeben, z. B. -500'
                      : 'Aktueller Stand des Kontos beim Anlegen',
                  prefixIcon: const Icon(Icons.euro),
                ),
              ),
              if (isLiability) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _creditLimit,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Kreditrahmen (optional)',
                    prefixIcon: Icon(Icons.speed_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                value: _includeInNetWorth,
                onChanged: (v) => setState(() => _includeInNetWorth = v),
                title: const Text('Zählt zum Gesamtvermögen'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
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
