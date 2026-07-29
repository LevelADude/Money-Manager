import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/models/account.dart';
import '../../data/models/user_currency.dart';
import '../../data/repositories/currency_repository.dart';
import '../accounts/account_providers.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';
import '../settings/settings_providers.dart';
import 'fx_service.dart';

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

final currencyRepositoryProvider = Provider<CurrencyRepository>((ref) {
  return CurrencyRepository(ref.watch(supabaseClientProvider));
});

/// Einmaliger Umzug der früher lokal (SharedPreferences) gespeicherten eigenen
/// Währungscodes + Wechselkurse in die DB. Läuft genau einmal pro Installation
/// nach dem Login und spiegelt zugleich die Basiswährung ins Profil.
final _currencyImportProvider = FutureProvider<void>((ref) async {
  final prefs = ref.watch(sharedPrefsProvider);
  if (prefs.getBool('currencies_migrated_v1') ?? false) return;
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return; // erst nach Login migrieren
  final repo = ref.watch(currencyRepositoryProvider);

  await repo.setMyBaseCurrency(ref.read(settingsProvider).baseCurrency);

  final codes =
      prefs.getStringList('settings_custom_currencies') ?? const <String>[];
  var rates = <String, dynamic>{};
  final raw = prefs.getString('settings_fx_rates');
  if (raw != null) {
    try {
      rates = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
  }
  for (final code in {...codes, ...rates.keys}) {
    final r = rates[code];
    await repo.upsert(code, r is num ? r.toDouble() : null);
  }
  await prefs.setBool('currencies_migrated_v1', true);
});

/// Alle sichtbaren Währungen aus der DB (eigene + die freigegebener Besitzer),
/// nach dem Einmal-Import.
final dbCurrenciesProvider = FutureProvider<List<UserCurrency>>((ref) async {
  await ref.watch(_currencyImportProvider.future);
  return ref.watch(currencyRepositoryProvider).fetchAll();
});

/// Meine eigenen Währungen.
final myCurrenciesProvider = Provider<List<UserCurrency>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  final all = ref.watch(dbCurrenciesProvider).value ?? const [];
  return [
    for (final c in all)
      if (c.ownerId == me) c,
  ];
});

/// Meine Kurse (Code -> Kurs zur Basiswährung) für den Kurs-Screen.
final myRatesProvider = Provider<Map<String, double>>((ref) {
  return {
    for (final c in ref.watch(myCurrenciesProvider))
      if (c.rateToBase != null) c.code: c.rateToBase!,
  };
});

/// Wählbare Währungen für die EIGENE Auswahl (Konto/Kurs anlegen): Standard +
/// eigene DB-Währungen + Währungen der EIGENEN Konten. Fremde (nur ansehbare)
/// Kontowährungen erscheinen hier bewusst NICHT.
final allCurrenciesProvider = Provider<List<String>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  final mine = ref.watch(myCurrenciesProvider).map((c) => c.code);
  final accs = ref.watch(accountsProvider).value ?? const <Account>[];
  final extras = <String>{
    ...mine,
    for (final a in accs)
      if (a.ownerId == me) a.currency,
  }..removeAll(supportedCurrencies);
  return [...supportedCurrencies, ...(extras.toList()..sort())];
});

// ----- Live-Wechselkurse (open.er-api.com) -----

const _kFxCacheKey = 'fx_live_rates_v1';
const _fxTtlMs = 6 * 60 * 60 * 1000; // 6 Stunden

final fxServiceProvider = Provider<FxService>((ref) => const FxService());

/// Zuletzt gespeicherte Live-Kurse (synchron aus den Prefs), damit direkt beim
/// Start ohne Netz gerechnet werden kann.
final cachedLiveRatesProvider = Provider<FxRates?>((ref) {
  final raw = ref.watch(sharedPrefsProvider).getString(_kFxCacheKey);
  if (raw == null) return null;
  try {
    return FxRates.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// Holt (bei Bedarf) frische Live-Kurse für die aktuelle Hauptwährung. Nutzt den
/// Prefs-Cache, solange er jung genug ist; bei Fehlern bleibt der Cache gültig.
final liveRatesProvider = FutureProvider<FxRates?>((ref) async {
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final prefs = ref.watch(sharedPrefsProvider);
  final cached = ref.read(cachedLiveRatesProvider);
  final now = DateTime.now().millisecondsSinceEpoch;
  if (cached != null &&
      cached.base == base &&
      (now - cached.fetchedAtMs) < _fxTtlMs) {
    return cached;
  }
  final fetched = await ref.read(fxServiceProvider).fetch(base);
  if (fetched != null) {
    await prefs.setString(_kFxCacheKey, jsonEncode(fetched.toJson()));
    return fetched;
  }
  return (cached != null && cached.base == base) ? cached : null;
});

/// Erzwingt das Neuladen der Live-Kurse (ignoriert den TTL) und aktualisiert den
/// Cache. Gibt `true` bei Erfolg zurück. Für den „Aktualisieren"-Knopf.
final refreshLiveRatesProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final base = ref.read(settingsProvider).baseCurrency;
    final fetched = await ref.read(fxServiceProvider).fetch(base);
    if (fetched == null) return false;
    await ref
        .read(sharedPrefsProvider)
        .setString(_kFxCacheKey, jsonEncode(fetched.toJson()));
    ref.invalidate(cachedLiveRatesProvider);
    ref.invalidate(liveRatesProvider);
    return true;
  };
});

/// Live-Kurse als Map (Code -> rate_to_base) für die aktuelle Hauptwährung,
/// synchron nutzbar (bevorzugt frisch geladen, sonst Cache). Leer, falls (noch)
/// nichts für diese Basiswährung vorliegt.
final liveRatesMapProvider = Provider<Map<String, double>>((ref) {
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final live =
      ref.watch(liveRatesProvider).value ?? ref.watch(cachedLiveRatesProvider);
  return (live != null && live.base == base)
      ? live.ratesToBase
      : const <String, double>{};
});

/// Wirksame Kurse für die Umrechnung in die eigene Basiswährung. Reihenfolge
/// (spätere gewinnen): eigene manuelle Kurse → Kurse fremder sichtbarer Besitzer
/// (gleiche Basis) → Live-Kurse aus dem Internet. So gelten für Weltwährungen
/// automatisch die Live-Kurse, während eigene (Krypto-)Währungen ihren manuell
/// gepflegten Kurs behalten (dort liefert die API nichts).
final effectiveRatesProvider = Provider<Map<String, double>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final all = ref.watch(dbCurrenciesProvider).value ?? const [];
  final ownerBases =
      ref.watch(profileBaseCurrenciesProvider).value ??
      const <String, String>{};
  final result = <String, double>{};
  for (final c in all) {
    if (c.ownerId == me && c.rateToBase != null) result[c.code] = c.rateToBase!;
  }
  for (final c in all) {
    if (c.ownerId == me || c.rateToBase == null) continue;
    if (result.containsKey(c.code)) continue;
    if ((ownerBases[c.ownerId] ?? 'EUR') == base) {
      result[c.code] = c.rateToBase!;
    }
  }
  // Live-Kurse überlagern (für Weltwährungen aktueller als manuelle Kurse).
  result.addAll(ref.watch(liveRatesMapProvider));
  return result;
});

/// Funktion: rechnet Cent einer Währung in die eigene Hauptwährung um.
final converterProvider = Provider<int Function(int cents, String code)>((ref) {
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final rates = ref.watch(effectiveRatesProvider);
  return (cents, code) {
    if (code == base) return cents;
    final r = rates[code];
    if (r == null) return cents; // unbekannt -> 1:1 (Nutzer sollte Kurs setzen)
    return (cents * r).round();
  };
});

/// Map: Konto-ID -> Währungscode (alle sichtbaren Konten).
final accountCurrencyProvider = Provider<Map<String, String>>((ref) {
  final accs = ref.watch(accountsProvider).value ?? const <Account>[];
  return {for (final a in accs) a.id: a.currency};
});

/// Währungen MEINER Konten (ohne Hauptwährung) — dafür setze ich eigene Kurse.
final usedForeignCurrenciesProvider = Provider<List<String>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  final base = ref.watch(settingsProvider.select((s) => s.baseCurrency));
  final accs = ref.watch(accountsProvider).value ?? const <Account>[];
  final set = <String>{
    for (final a in accs)
      if (a.ownerId == me) a.currency,
  }..remove(base);
  return set.toList()..sort();
});
