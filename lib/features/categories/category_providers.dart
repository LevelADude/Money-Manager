import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/models/category.dart';
import '../../data/models/category_pref.dart';
import '../../data/models/category_rule.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../settings/settings_providers.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appCacheProvider),
  );
});

/// Live-Liste ALLER Kategorien (gruppenweit, ohne persönliches Overlay). Basis
/// für Namens-Auflösung (auch ausgeblendeter Kategorien) und für die effektive
/// Liste unten.
final categoriesRawProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories();
});

/// Persönliche Overlay-Einstellungen (Kategorie-ID -> [CategoryPref]).
final categoryPrefsProvider = StreamProvider<Map<String, CategoryPref>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchMyPrefs();
});

/// Effektive Kategorien-Liste für Verwaltung UND Auswahl: persönliche
/// Reihenfolge/Aktiv-Overlays angewendet, ausgeblendete entfernt.
final categoriesProvider = Provider<AsyncValue<List<Category>>>((ref) {
  final rawAsync = ref.watch(categoriesRawProvider);
  final prefs = ref.watch(categoryPrefsProvider).value ?? const {};
  return rawAsync.whenData((raw) {
    final list = <Category>[];
    for (final c in raw) {
      final p = prefs[c.id];
      if (p?.hidden ?? false) continue;
      list.add(c.copyWith(active: p?.active, sortOrder: p?.sortOrder));
    }
    list.sort((a, b) {
      final s = a.sortOrder.compareTo(b.sortOrder);
      return s != 0 ? s : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  });
});

/// Vom Nutzer ausgeblendete Kategorien (zum Wiedereinblenden in der Verwaltung).
final hiddenCategoriesProvider = Provider<List<Category>>((ref) {
  final raw = ref.watch(categoriesRawProvider).value ?? const <Category>[];
  final prefs = ref.watch(categoryPrefsProvider).value ?? const {};
  return [
    for (final c in raw)
      if (prefs[c.id]?.hidden ?? false) c,
  ];
});

/// Map: Kategorie-ID -> Anzeigename (für Anzeige auf Buchungen). Preset-Namen
/// werden gemäß eingestellter Sprache übersetzt. Nutzt die ROH-Liste, damit auch
/// ausgeblendete Kategorien noch aufgelöst werden.
final categoryNamesProvider = Provider<Map<String, String>>((ref) {
  final cats = ref.watch(categoriesRawProvider).value ?? const <Category>[];
  final l = AppLocalizations(
    Locale(ref.watch(settingsProvider.select((s) => s.localeCode))),
  );
  return {for (final c in cats) c.id: l.categoryName(c)};
});

/// Map: Kategorie-ID -> ROHER (unübersetzter) Name. Für den CSV-Export/-Import,
/// dessen Format bewusst deutsch bleibt (Round-Trip-Abgleich nach Name).
final categoryRawNamesProvider = Provider<Map<String, String>>((ref) {
  final cats = ref.watch(categoriesRawProvider).value ?? const <Category>[];
  return {for (final c in cats) c.id: c.name};
});

/// Auto-Kategorisierungs-Regeln (Live).
final categoryRulesProvider = StreamProvider<List<CategoryRule>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchRules();
});
