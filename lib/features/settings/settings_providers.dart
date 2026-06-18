import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';

/// App-Einstellungen (Theme-Modus + Akzentfarbe), lokal gespeichert.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedColor = 0xFF2E7D32,
  });

  final ThemeMode themeMode;
  final int seedColor;

  AppSettings copyWith({ThemeMode? themeMode, int? seedColor}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        seedColor: seedColor ?? this.seedColor,
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

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final modeIdx = prefs.getInt(_kMode) ?? ThemeMode.system.index;
    final seed = prefs.getInt(_kSeed) ?? 0xFF2E7D32;
    return AppSettings(
      themeMode: ThemeMode.values[modeIdx.clamp(0, ThemeMode.values.length - 1)],
      seedColor: seed,
    );
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

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
