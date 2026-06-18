import 'package:flutter/material.dart';

/// Dialog zum Eingeben eines eigenen Währungscodes (z. B. BTC). Gibt den
/// Code in Großbuchstaben zurück oder null bei Abbruch.
Future<String?> showAddCurrencyDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eigene Währung'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 5,
        decoration: const InputDecoration(
          labelText: 'Währungscode (z. B. BTC)',
          helperText: 'Kurs später unter „Wechselkurse" festlegen.',
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()),
          child: const Text('Hinzufügen'),
        ),
      ],
    ),
  );
  return (code == null || code.isEmpty) ? null : code;
}
