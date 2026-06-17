import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/category.dart';

/// Zugriff auf die Tabelle `categories` (gruppenweit) inkl. Stream + Cache.
class CategoryRepository {
  CategoryRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  Stream<List<Category>> watchCategories() async* {
    final cached = _cache.readRows('categories');
    if (cached.isNotEmpty) {
      yield cached
          .where((r) => r['deleted_at'] == null)
          .map(Category.fromJson)
          .toList();
    }
    try {
      yield* _client
          .from('categories')
          .stream(primaryKey: ['id'])
          .order('name')
          .map((rows) {
        _cache.writeRows('categories', rows);
        return rows
            .where((r) => r['deleted_at'] == null)
            .map(Category.fromJson)
            .toList();
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  Future<void> addCategory({
    required String name,
    required CategoryKind kind,
    String? icon,
  }) {
    return _client.from('categories').insert({
      'name': name,
      'kind': categoryKindToDb(kind),
      'icon': icon,
      'is_preset': false,
    });
  }

  Future<void> setActive({required String id, required bool active}) {
    return _client.from('categories').update({'active': active}).eq('id', id);
  }

  /// Soft-Delete (Tombstone); Buchungen behalten ihre (nun verwaiste) Referenz.
  Future<void> deleteCategory(String id) {
    return _client
        .from('categories')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
