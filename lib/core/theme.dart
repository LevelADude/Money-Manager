import 'package:flutter/material.dart';

/// Zentrales App-Theme (hell + dunkel), Material 3, mit wählbarer Akzentfarbe.
class AppTheme {
  const AppTheme._();

  static const Color defaultSeed = Color(0xFF2E7D32); // grün = Finanzen

  static ThemeData light([Color seed = defaultSeed]) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
  );

  static ThemeData dark([Color seed = defaultSeed]) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ),
  );
}
