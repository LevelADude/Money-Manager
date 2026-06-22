import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/account.dart';
import '../accounts/account_providers.dart';
import '../settings/settings_providers.dart';

const supportedCurrencies = <String>[
  'EUR',
  'USD',
  'GBP',
  'CHF',
  'JPY',
  'PLN',
  'SEK',
  'NOK',
  'DKK',
  'CZK',
  'TRY',
  'CAD',
  'AUD',
  'USDT',
];

/// Vom Nutzer hinzugefügte eigene Währungscodes (lokal gespeichert).
class CustomCurrenciesNotifier extends Notifier<List<String>> {
  static const _k = 'settings_custom_currencies';

  @override
  List<String> build() =>
      ref.watch(sharedPrefsProvider).getStringList(_k) ?? const [];

  Future<void> add(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty || supportedCurrencies.contains(c) || state.contains(c)) {
      return;
    }
    final next = [...state, c];
    await ref.read(sharedPrefsProvider).setStringList(_k, next);
    state = next;
  }
}

final customCurrenciesProvider =
    NotifierProvider<CustomCurrenciesNotifier, List<String>>(
      CustomCurrenciesNotifier.new,
    );

/// Alle wählbaren Währungen: Standard + eigene + in Konten benutzte.
final allCurrenciesProvider = Provider<List<String>>((ref) {
  final custom = ref.watch(customCurrenciesProvider);
  final accs = ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final extras = <String>{...custom, for (final a in accs) a.currency}
    ..removeAll(supportedCurrencies);
  return [...supportedCurrencies, ...(extras.toList()..sort())];
});

/// Wechselkurse: wie viele Einheiten der Hauptwährung 1 Einheit der Währung
/// wert ist (Hauptwährung selbst = 1.0). Lokal in shared_preferences.
class ExchangeRatesNotifier extends Notifier<Map<String, double>> {
  static const _k = 'settings_fx_rates';

  @override
  Map<String, double> build() {
    final raw = ref.watch(sharedPrefsProvider).getString(_k);
    if (raw == null) return const {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in m.entries) e.key: (e.value as num).toDouble()};
    } catch (_) {
      return const {};
    }
  }

  Future<void> setRate(String code, double rate) async {
    final next = {...state, code: rate};
    await ref.read(sharedPrefsProvider).setString(_k, jsonEncode(next));
    state = next;
  }

  Future<void> removeRate(String code) async {
    final next = {...state}..remove(code);
    await ref.read(sharedPrefsProvider).setString(_k, jsonEncode(next));
    state = next;
  }
}

final exchangeRatesProvider =
    NotifierProvider<ExchangeRatesNotifier, Map<String, double>>(
      ExchangeRatesNotifier.new,
    );

/// Funktion: rechnet Cent einer Währung in die Hauptwährung um.
final converterProvider = Provider<int Function(int cents, String code)>((ref) {
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final rates = ref.watch(exchangeRatesProvider);
  return (cents, code) {
    if (code == base) return cents;
    final r =
        rates[code] ?? 1.0; // unbekannt -> 1:1 (Nutzer sollte Kurs setzen)
    return (cents * r).round();
  };
});

/// Map: Konto-ID -> Währungscode.
final accountCurrencyProvider = Provider<Map<String, String>>((ref) {
  final accs = ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  return {for (final a in accs) a.id: a.currency};
});

/// Währungen, die tatsächlich in Konten verwendet werden (ohne Hauptwährung).
final usedForeignCurrenciesProvider = Provider<List<String>>((ref) {
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final accs = ref.watch(accountsProvider).asData?.value ?? const <Account>[];
  final set = {for (final a in accs) a.currency}..remove(base);
  final list = set.toList()..sort();
  return list;
});
