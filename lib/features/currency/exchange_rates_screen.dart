import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/money.dart';
import '../settings/settings_providers.dart';
import 'currency_providers.dart';

/// Wechselkurse verwalten: wie viele Einheiten der Hauptwährung 1 Einheit einer
/// Fremdwährung wert ist (z. B. 1 USD = 0,92 EUR).
class ExchangeRatesScreen extends ConsumerWidget {
  const ExchangeRatesScreen({super.key});

  Future<void> _editRate(
      BuildContext context, WidgetRef ref, String code, double current) async {
    final ctrl = TextEditingController(
        text: current == 0 ? '' : current.toString().replaceAll('.', ','));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kurs für $code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '1 $code = ? ${ref.read(settingsProvider).baseCurrency}',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true) {
      final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
      if (v != null && v > 0) {
        await ref.read(exchangeRatesProvider.notifier).setRate(code, v);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
    final rates = ref.watch(exchangeRatesProvider);
    final used = ref.watch(usedForeignCurrenciesProvider);
    // Alle Fremdwährungen anzeigen, für die es einen Kurs gibt oder die genutzt werden.
    final codes = <String>{...used, ...rates.keys}..remove(base);
    final list = codes.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Wechselkurse')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.star_outline),
              title: Text('Hauptwährung: $base'),
              subtitle: const Text('Basis (Kurs = 1,00)'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lege fest, wie viel 1 Einheit einer Fremdwährung in $base wert ist. '
            'Beträge auf Fremdwährungs-Konten werden damit in Summen umgerechnet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'Keine Fremdwährungen in Benutzung. Lege ein Konto mit anderer '
                  'Währung an oder füge unten einen Kurs hinzu.'),
            )
          else
            for (final code in list)
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: Text('1 $code (${currencySymbol(code)})'),
                subtitle: Text(rates[code] == null
                    ? 'Kein Kurs gesetzt (wird 1:1 gerechnet)'
                    : '= ${rates[code].toString().replaceAll('.', ',')} $base'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () =>
                    _editRate(context, ref, code, rates[code] ?? 0),
              ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            children: [
              for (final c in supportedCurrencies)
                if (c != base && !codes.contains(c))
                  ActionChip(
                    label: Text(c),
                    avatar: const Icon(Icons.add, size: 16),
                    onPressed: () => _editRate(context, ref, c, 0),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
