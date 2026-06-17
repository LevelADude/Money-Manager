import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_cache.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/models/category.dart';
import '../auth/auth_providers.dart';

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

/// Map: Kategorie-ID -> Name (für Anzeige auf Buchungen).
final categoryNamesProvider = Provider<Map<String, String>>((ref) {
  final cats = ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
  return {for (final c in cats) c.id: c.name};
});
