import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../shared/money.dart' show gBaseCurrency;

/// App-Einstellungen (Theme-Modus + Akzentfarbe), lokal gespeichert.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedColor = 0xFF2E7D32,
    this.hideAmounts = false,
    this.lockEnabled = false,
    this.baseCurrency = 'EUR',
    this.localeCode = 'de',
  });

  final ThemeMode themeMode;
  final int seedColor;

  /// Beträge in der Oberfläche verbergen (Privatsphäre).
  final bool hideAmounts;

  /// App-Sperre per PIN aktiv.
  final bool lockEnabled;

  /// Hauptwährung für Summen/Umrechnung.
  final String baseCurrency;

  /// Sprachcode der Oberfläche ('de' oder 'en').
  final String localeCode;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? seedColor,
    bool? hideAmounts,
    bool? lockEnabled,
    String? baseCurrency,
    String? localeCode,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    seedColor: seedColor ?? this.seedColor,
    hideAmounts: hideAmounts ?? this.hideAmounts,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    localeCode: localeCode ?? this.localeCode,
  );
}

/// Auswählbare Akzentfarben.
const accentColors = <int>[
  0xFF2E7D32, // Grün (Standard)
  0xFF1565C0, // Blau
  0xFF6A1B9A, // Violett
  0xFFC62828, // Rot
  0xFFEF6C00, // Orange
  0xFF00838F, // Petrol
  0xFF4E342E, // Braun
  0xFF37474F, // Blaugrau
];

class SettingsNotifier extends Notifier<AppSettings> {
  static const _kMode = 'settings_theme_mode';
  static const _kSeed = 'settings_seed_color';
  static const _kHide = 'settings_hide_amounts';
  static const _kPinHash = 'settings_pin_hash';
  static const _kPinSalt = 'settings_pin_salt';
  static const _kBaseCur = 'settings_base_currency';
  static const _kLocale = 'settings_locale';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final modeIdx = prefs.getInt(_kMode) ?? ThemeMode.system.index;
    final seed = prefs.getInt(_kSeed) ?? 0xFF2E7D32;
    final base = prefs.getString(_kBaseCur) ?? 'EUR';
    gBaseCurrency = base; // globalen Formatter aktualisieren
    final loc = prefs.getString(_kLocale) ?? 'de';
    return AppSettings(
      themeMode:
          ThemeMode.values[modeIdx.clamp(0, ThemeMode.values.length - 1)],
      seedColor: seed,
      hideAmounts: prefs.getBool(_kHide) ?? false,
      lockEnabled: prefs.getString(_kPinHash) != null,
      baseCurrency: base,
      localeCode: loc == 'en' ? 'en' : 'de',
    );
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

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(sharedPrefsProvider).setInt(_kMode, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setSeedColor(int color) async {
    await ref.read(sharedPrefsProvider).setInt(_kSeed, color);
    state = state.copyWith(seedColor: color);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
