import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../../shared/money.dart';
import '../auth/auth_providers.dart';
import '../currency/add_currency.dart';
import '../currency/currency_providers.dart';
import '../profile/profile_providers.dart';
import '../sharing/account_member_providers.dart';
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
  String _currency = 'EUR';
  bool _includeInNetWorth = true;
  bool _saving = false;
  bool _prefilled = false;
  String? _ownerId; // Besitzer (bei Bearbeitung), für „nur Besitzer teilt"
  Set<String> _shareWith = {}; // Mitglieder eines geteilten Kontos
  bool _membersInit = false;

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
        _currency = a.currency;
        _opening.text = centsToInput(a.openingBalanceCents);
        _creditLimit.text =
            a.creditLimitCents == null ? '' : centsToInput(a.creditLimitCents!);
        _includeInNetWorth = a.includeInNetWorth;
        _ownerId = a.ownerId;
        _prefilled = true;
        break;
      }
    }
  }

  Future<void> _save() async {
    // Re-Entry-Schutz: verhindert doppelte Konten bei schnellem Doppel-Tipp
    // (der Button-Disable greift erst nach dem Rebuild – diese Sperre sofort).
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final openingCents = parseToCents(_opening.text) ?? 0;
    final creditCents =
        _creditLimit.text.trim().isEmpty ? null : parseToCents(_creditLimit.text);
    setState(() => _saving = true);
    final repo = ref.read(accountRepositoryProvider);
    final myId = ref.read(currentUserIdProvider);
    final isOwner = !widget.isEditing || _ownerId == myId;
    try {
      String id;
      if (widget.isEditing) {
        await repo.updateAccount(
          id: widget.accountId!,
          name: _name.text.trim(),
          type: _type,
          openingBalanceCents: openingCents,
          includeInNetWorth: _includeInNetWorth,
          currency: _currency,
          creditLimitCents: creditCents,
        );
        id = widget.accountId!;
      } else {
        id = await repo.createAccount(
          name: _name.text.trim(),
          type: _type,
          openingBalanceCents: openingCents,
          includeInNetWorth: _includeInNetWorth,
          currency: _currency,
          creditLimitCents: creditCents,
        );
      }
      // Mitglieder geteilter Konten setzen (nur der Besitzer darf das).
      if (isOwner) {
        await ref
            .read(accountMemberRepositoryProvider)
            .setMembers(id, _shareWith);
      }
      ref.invalidate(accountsProvider);
      ref.invalidate(accountMembersProvider);
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
    final myId = ref.watch(currentUserIdProvider);
    // Nur der Besitzer eines Kontos darf es teilen (neu: ich bin Besitzer).
    final isOwner = !widget.isEditing || _ownerId == myId;
    // Vorhandene Mitglieder beim Bearbeiten einmalig vorbelegen.
    if (widget.isEditing && !_membersInit &&
        ref.watch(accountMembersProvider).hasValue) {
      _shareWith = {...?ref.read(membersByAccountProvider)[widget.accountId]};
      _membersInit = true;
    }
    final profileNames =
        ref.watch(profileNamesProvider).asData?.value ?? const <String, String>{};
    final others = profileNames.keys.where((id) => id != myId).toList()
      ..sort((a, b) => (profileNames[a] ?? '')
          .toLowerCase()
          .compareTo((profileNames[b] ?? '').toLowerCase()));
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
              Consumer(builder: (context, ref, _) {
                final all = ref.watch(allCurrenciesProvider);
                final value = all.contains(_currency) ? _currency : 'EUR';
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: value,
                        decoration: const InputDecoration(
                          labelText: 'Währung',
                          prefixIcon: Icon(Icons.currency_exchange),
                        ),
                        items: [
                          for (final c in all)
                            DropdownMenuItem(
                                value: c,
                                child: Text('$c (${currencySymbol(c)})')),
                        ],
                        onChanged: (v) => setState(() => _currency = v ?? 'EUR'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eigene Währung hinzufügen',
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final code = await showAddCurrencyDialog(context);
                        if (code != null) {
                          await ref
                              .read(customCurrenciesProvider.notifier)
                              .add(code);
                          setState(() => _currency = code);
                        }
                      },
                    ),
                  ],
                );
              }),
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
              if (isOwner && others.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Teilen mit (Gemeinschaftskonto)',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ausgewählte Personen sehen dieses Konto und dürfen darauf buchen.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final id in others)
                      FilterChip(
                        label: Text(profileNames[id]!.isNotEmpty
                            ? profileNames[id]!
                            : 'Unbekannt'),
                        selected: _shareWith.contains(id),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _shareWith.add(id);
                          } else {
                            _shareWith.remove(id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
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
