import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/category.dart';

/// Zugriff auf die Tabelle `categories` (gruppenweit) inkl. Stream + Cache.
class CategoryRepository {
  CategoryRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  // Sortierung: erst nach selbst festgelegter Reihenfolge, dann nach Name.
  List<Category> _sorted(Iterable<Category> cats) {
    final list = cats.toList()
      ..sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  Stream<List<Category>> watchCategories() async* {
    final cached = _cache.readRows('categories');
    if (cached.isNotEmpty) {
      yield _sorted(cached
          .where((r) => r['deleted_at'] == null)
          .map(Category.fromJson));
    }
    try {
      yield* _client
          .from('categories')
          .stream(primaryKey: ['id'])
          .order('sort_order')
          .map((rows) {
        _cache.writeRows('categories', rows);
        return _sorted(rows
            .where((r) => r['deleted_at'] == null)
            .map(Category.fromJson));
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  /// Speichert eine neue Reihenfolge (id -> sort_order).
  Future<void> reorder(List<({String id, int sortOrder})> orders) async {
    await Future.wait([
      for (final o in orders)
        _client
            .from('categories')
            .update({'sort_order': o.sortOrder}).eq('id', o.id),
    ]);
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
