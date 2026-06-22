import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../settings/settings_providers.dart';
import 'add_currency.dart';
import 'currency_providers.dart';

/// Wechselkurse verwalten: wie viele Einheiten der Hauptwährung 1 Einheit einer
/// Fremdwährung wert ist (z. B. 1 USD = 0,92 EUR).
class ExchangeRatesScreen extends ConsumerWidget {
  const ExchangeRatesScreen({super.key});

  Future<void> _editRate(
    BuildContext context,
    WidgetRef ref,
    String code,
    double current,
  ) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(
      text: current == 0 ? '' : current.toString().replaceAll('.', ','),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.rateForCode(code)),
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
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.save),
          ),
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
    final l = AppLocalizations.of(context);
    // Alle Fremdwährungen anzeigen, für die es einen Kurs gibt oder die genutzt werden.
    final codes = <String>{...used, ...rates.keys}..remove(base);
    final list = codes.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(l.exchangeRatesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.star_outline),
              title: Text(l.mainCurrencyWith(base)),
              subtitle: Text(l.baseRateNote),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.exchangeRatesIntro(base),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.noForeignCurrencies),
            )
          else
            for (final code in list)
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: Text('1 $code (${currencySymbol(code)})'),
                subtitle: Text(
                  rates[code] == null
                      ? l.noRateSet
                      : '= ${rates[code].toString().replaceAll('.', ',')} $base',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editRate(context, ref, code, rates[code] ?? 0),
              ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            children: [
              for (final c in ref.watch(allCurrenciesProvider))
                if (c != base && !codes.contains(c))
                  ActionChip(
                    label: Text(c),
                    avatar: const Icon(Icons.add, size: 16),
                    onPressed: () => _editRate(context, ref, c, 0),
                  ),
              ActionChip(
                label: Text(l.customEllipsis),
                avatar: const Icon(Icons.add, size: 16),
                onPressed: () async {
                  final code = await showAddCurrencyDialog(context);
                  if (code == null) return;
                  await ref.read(customCurrenciesProvider.notifier).add(code);
                  if (context.mounted) await _editRate(context, ref, code, 0);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
