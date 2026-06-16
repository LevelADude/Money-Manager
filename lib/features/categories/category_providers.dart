import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import '../auth/auth_providers.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(supabaseClientProvider));
});

/// Live-Liste der Kategorien eines Buchs.
final categoriesProvider =
    StreamProvider.family<List<Category>, String>((ref, ledgerId) {
  return ref.watch(categoryRepositoryProvider).watchCategories(ledgerId);
});
