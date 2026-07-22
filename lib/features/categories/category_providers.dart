import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/models/category.dart';
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

/// Live-Liste aller (gruppenweiten) Kategorien.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories();
});

/// Map: Kategorie-ID -> Anzeigename (für Anzeige auf Buchungen). Preset-Namen
/// werden gemäß eingestellter Sprache übersetzt.
final categoryNamesProvider = Provider<Map<String, String>>((ref) {
  final cats =
      ref.watch(categoriesProvider).value ?? const <Category>[];
  final l = AppLocalizations(
    Locale(ref.watch(settingsProvider.select((s) => s.localeCode))),
  );
  return {for (final c in cats) c.id: l.categoryName(c)};
});

/// Map: Kategorie-ID -> ROHER (unübersetzter) Name. Für den CSV-Export/-Import,
/// dessen Format bewusst deutsch bleibt (Round-Trip-Abgleich nach Name).
final categoryRawNamesProvider = Provider<Map<String, String>>((ref) {
  final cats =
      ref.watch(categoriesProvider).value ?? const <Category>[];
  return {for (final c in cats) c.id: c.name};
});

/// Auto-Kategorisierungs-Regeln (Live).
final categoryRulesProvider = StreamProvider<List<CategoryRule>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchRules();
});
