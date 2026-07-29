import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/money.dart';
import '../settings/settings_providers.dart';
import 'currency_picker.dart';
import 'currency_providers.dart';

/// Wechselkurse verwalten: wie viele Einheiten der Hauptwährung 1 Einheit einer
/// Fremdwährung wert ist (z. B. 1 USD = 0,92 EUR). Nur eigene Währungen/Kurse;
/// Konten anderer Personen werden mit deren eigenen Kursen umgerechnet.
class ExchangeRatesScreen extends ConsumerWidget {
  const ExchangeRatesScreen({super.key});

  /// Formatiert einen Kurs kompakt (bis 8 Nachkommastellen, ohne unnötige
  /// Nullen, Komma als Dezimaltrenner).
  static String _fmtRate(double v) {
    var s = v.toStringAsFixed(8);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', ',');
  }

  Future<void> _editRate(
    BuildContext context,
    WidgetRef ref,
    String code,
    double current,
  ) async {
    final l = AppLocalizations.of(context);
    final base = ref.read(settingsProvider).baseCurrency;
    // `current` ist der Kurs zur Basiswährung (1 code = current base).
    final ctrl = TextEditingController(
      text: current == 0 ? '' : _fmtRate(current),
    );
    // false: „1 code = ? base"; true: umgekehrt „1 base = ? code".
    var inverse = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          void switchTo(bool inv) {
            if (inv == inverse) return;
            final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
            setState(() {
              inverse = inv;
              if (v != null && v > 0) ctrl.text = _fmtRate(1 / v);
            });
          }

          return AlertDialog(
            title: Text(l.rateForCode(code)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text('$code → $base')),
                    ButtonSegment(value: true, label: Text('$base → $code')),
                  ],
                  selected: {inverse},
                  onSelectionChanged: (s) => switchTo(s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: inverse
                        ? '1 $base = ? $code'
                        : '1 $code = ? $base',
                  ),
                ),
              ],
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
          );
        },
      ),
    );
    if (ok == true) {
      final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
      if (v != null && v > 0) {
        // Immer als Kurs zur Basiswährung speichern (rate_to_base).
        final rate = inverse ? 1 / v : v;
        await ref.read(currencyRepositoryProvider).upsert(code, rate);
        ref.invalidate(dbCurrenciesProvider);
      }
    }
  }

  Future<void> _deleteCurrency(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    final l = AppLocalizations.of(context);
    // Von einem eigenen Konto benutzte Währung nicht löschbar.
    final used = ref.read(usedForeignCurrenciesProvider).contains(code);
    if (used) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.currencyInUse(code))));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteCurrency),
        content: Text('$code (${currencySymbol(code)})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(currencyRepositoryProvider).remove(code);
      ref.invalidate(dbCurrenciesProvider);
    }
  }

  /// Erzwingt frische Live-Kurse und meldet das Ergebnis.
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(refreshLiveRatesProvider)();
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l.ratesUpdated : l.ratesUpdateFailed)),
    );
  }

  /// Fügt eine Währung über die durchsuchbare Auswahl hinzu. Für Weltwährungen
  /// genügt der Live-Kurs; bei eigenen (ohne Live) wird direkt der Kurs abgefragt.
  Future<void> _addCurrency(
    BuildContext context,
    WidgetRef ref,
    String base,
  ) async {
    final extras = ref.read(myCurrenciesProvider).map((c) => c.code).toList();
    final code = await showCurrencyPicker(context, extraCodes: extras);
    if (code == null || code == base) return;
    await ref.read(currencyRepositoryProvider).upsert(code, null);
    ref.invalidate(dbCurrenciesProvider);
    final hasLive = ref.read(liveRatesMapProvider).containsKey(code);
    if (!hasLive && context.mounted) await _editRate(context, ref, code, 0);
  }

  Widget _rateSubtitle(
    AppLocalizations l,
    String code,
    String base,
    Map<String, double> effective,
    Map<String, double> live,
  ) {
    final rate = effective[code];
    if (rate == null) return Text(l.noRateSet);
    final source = live.containsKey(code) ? l.liveRate : l.manualRate;
    return Text('= ${_fmtRate(rate)} $base · $source');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
    final manual = ref.watch(myRatesProvider);
    final live = ref.watch(liveRatesMapProvider);
    final effective = ref.watch(effectiveRatesProvider);
    final used = ref.watch(usedForeignCurrenciesProvider);
    final mine = ref.watch(myCurrenciesProvider).map((c) => c.code);
    final l = AppLocalizations.of(context);
    // Alle eigenen Fremdwährungen: benutzt in eigenen Konten oder selbst
    // angelegt / mit Kurs versehen. Live-Währungen ohne eigenen Eintrag müssen
    // nicht separat gepflegt werden (Umrechnung läuft automatisch).
    final codes = <String>{...used, ...mine, ...manual.keys}..remove(base);
    final list = codes.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.exchangeRatesTitle),
        actions: [
          IconButton(
            tooltip: l.refreshRates,
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCurrency(context, ref, base),
        icon: const Icon(Icons.add),
        label: Text(l.addCurrency),
      ),
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
          const SizedBox(height: 4),
          Text(
            l.foreignAccountsRatesNote,
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
                subtitle: _rateSubtitle(l, code, base, effective, live),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l.deleteCurrency,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteCurrency(context, ref, code),
                    ),
                    const Icon(Icons.edit_outlined),
                  ],
                ),
                onTap: () => _editRate(context, ref, code, manual[code] ?? 0),
              ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
