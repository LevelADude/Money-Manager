import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/local/app_cache.dart';
import '../../data/repositories/currency_repository.dart';
import '../../shared/money.dart' show gBaseCurrency;
import '../auth/auth_providers.dart';

/// App-Einstellungen (Palette, Privatsphäre, Währung, Sprache), lokal gespeichert.
class AppSettings {
  const AppSettings({
    this.palette = AppPalette.system,
    this.hideAmounts = false,
    this.lockEnabled = false,
    this.baseCurrency = 'EUR',
    this.displayCurrencies = const [],
    this.localeCode = 'de',
    this.showAvailable = true,
  });

  /// Farbpalette der Oberfläche; `system` folgt Hell/Dunkel des Geräts.
  final AppPalette palette;

  /// Beträge in der Oberfläche verbergen (Privatsphäre).
  final bool hideAmounts;

  /// App-Sperre per PIN aktiv.
  final bool lockEnabled;

  /// Hauptwährung für Summen/Umrechnung.
  final String baseCurrency;

  /// Zusätzliche Anzeigewährungen: Gesamtsummen werden zusätzlich in diesen
  /// Währungen ausgewiesen (Live-Umrechnung). Leer = nur Hauptwährung.
  final List<String> displayCurrencies;

  /// Sprachcode der Oberfläche ('de' oder 'en').
  final String localeCode;

  /// Salden als „verfügbar" (abzüglich Reservierungen) groß anzeigen und den
  /// Gesamtbetrag klein darunter — oder umgekehrt.
  final bool showAvailable;

  AppSettings copyWith({
    AppPalette? palette,
    bool? hideAmounts,
    bool? lockEnabled,
    String? baseCurrency,
    List<String>? displayCurrencies,
    String? localeCode,
    bool? showAvailable,
  }) => AppSettings(
    palette: palette ?? this.palette,
    hideAmounts: hideAmounts ?? this.hideAmounts,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    displayCurrencies: displayCurrencies ?? this.displayCurrencies,
    localeCode: localeCode ?? this.localeCode,
    showAvailable: showAvailable ?? this.showAvailable,
  );
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _kMode = 'settings_theme_mode';
  static const _kPalette = 'settings_palette';
  static const _kHide = 'settings_hide_amounts';
  static const _kPinHash = 'settings_pin_hash';
  static const _kPinSalt = 'settings_pin_salt';
  static const _kBaseCur = 'settings_base_currency';
  static const _kDisplayCur = 'settings_display_currencies';
  static const _kLocale = 'settings_locale';
  static const _kShowAvailable = 'settings_show_available';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final palette = _readPalette(
      prefs.getString(_kPalette),
      prefs.getInt(_kMode),
    );
    final base = prefs.getString(_kBaseCur) ?? 'EUR';
    gBaseCurrency = base; // globalen Formatter aktualisieren
    final loc = prefs.getString(_kLocale) ?? 'de';
    return AppSettings(
      palette: palette,
      hideAmounts: prefs.getBool(_kHide) ?? false,
      lockEnabled: prefs.getString(_kPinHash) != null,
      baseCurrency: base,
      displayCurrencies: prefs.getStringList(_kDisplayCur) ?? const <String>[],
      localeCode: loc == 'en' ? 'en' : 'de',
      showAvailable: prefs.getBool(_kShowAvailable) ?? true,
    );
  }

  /// Gespeicherte Palette lesen. Fehlt sie (Stand vor dem Redesign), wird der
  /// alte Hell/Dunkel-Schalter übernommen: 1 = hell → Salbei, 2 = dunkel.
  static AppPalette _readPalette(String? name, int? legacyMode) {
    for (final p in AppPalette.values) {
      if (p.name == name) return p;
    }
    return switch (legacyMode) {
      1 => AppPalette.sage,
      2 => AppPalette.dark,
      _ => AppPalette.system,
    };
  }

  /// Setzt die zusätzlichen Anzeigewährungen (ohne die Hauptwährung selbst).
  Future<void> setDisplayCurrencies(List<String> codes) async {
    final base = state.baseCurrency;
    final cleaned = <String>[
      for (final c in codes)
        if (c != base) c,
    ];
    await ref.read(sharedPrefsProvider).setStringList(_kDisplayCur, cleaned);
    state = state.copyWith(displayCurrencies: cleaned);
  }

  Future<void> setLocale(String code) async {
    final c = code == 'en' ? 'en' : 'de';
    await ref.read(sharedPrefsProvider).setString(_kLocale, c);
    state = state.copyWith(localeCode: c);
  }

  Future<void> setBaseCurrency(String code) async {
    await ref.read(sharedPrefsProvider).setString(_kBaseCur, code);
    gBaseCurrency = code;
    state = state.copyWith(baseCurrency: code);
    // Basiswährung ins Profil spiegeln, damit andere Nutzer die eigenen Kurse
    // korrekt deuten können (fehlerresistent: Offline/kein Login egal).
    try {
      await CurrencyRepository(
        ref.read(supabaseClientProvider),
      ).setMyBaseCurrency(code);
    } catch (_) {}
  }

  Future<void> setShowAvailable(bool value) async {
    await ref.read(sharedPrefsProvider).setBool(_kShowAvailable, value);
    state = state.copyWith(showAvailable: value);
  }

  Future<void> setHideAmounts(bool hide) async {
    await ref.read(sharedPrefsProvider).setBool(_kHide, hide);
    state = state.copyWith(hideAmounts: hide);
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// Setzt/ändert die PIN und aktiviert die App-Sperre.
  Future<void> setPin(String pin) async {
    final prefs = ref.read(sharedPrefsProvider);
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    await prefs.setString(_kPinSalt, salt);
    await prefs.setString(_kPinHash, _hash(pin, salt));
    state = state.copyWith(lockEnabled: true);
  }

  Future<void> disableLock() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove(_kPinHash);
    await prefs.remove(_kPinSalt);
    state = state.copyWith(lockEnabled: false);
  }

  bool verifyPin(String pin) {
    final prefs = ref.read(sharedPrefsProvider);
    final salt = prefs.getString(_kPinSalt);
    final hash = prefs.getString(_kPinHash);
    if (salt == null || hash == null) return true;
    return _hash(pin, salt) == hash;
  }

  Future<void> setPalette(AppPalette palette) async {
    await ref.read(sharedPrefsProvider).setString(_kPalette, palette.name);
    state = state.copyWith(palette: palette);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
