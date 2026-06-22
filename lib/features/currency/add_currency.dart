import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Dialog zum Eingeben eines eigenen Währungscodes (z. B. BTC). Gibt den
/// Code in Großbuchstaben zurück oder null bei Abbruch.
Future<String?> showAddCurrencyDialog(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final ctrl = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.customCurrency),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 5,
        decoration: InputDecoration(
          labelText: l.currencyCodeLabel,
          helperText: l.currencyCodeHelper,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()),
          child: Text(l.add),
        ),
      ],
    ),
  );
  return (code == null || code.isEmpty) ? null : code;
}
