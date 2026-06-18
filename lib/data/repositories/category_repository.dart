import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/category.dart';
import '../models/category_rule.dart';

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

  // ----- Auto-Kategorisierungs-Regeln -----

  Stream<List<CategoryRule>> watchRules() async* {
    final cached = _cache.readRows('category_rules');
    if (cached.isNotEmpty) {
      yield cached.map(CategoryRule.fromJson).toList();
    }
    try {
      yield* _client
          .from('category_rules')
          .stream(primaryKey: ['id'])
          .order('keyword')
          .map((rows) {
        _cache.writeRows('category_rules', rows);
        return rows.map(CategoryRule.fromJson).toList();
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  Future<void> addRule({required String keyword, required String categoryId}) {
    return _client.from('category_rules').insert({
      'keyword': keyword.trim(),
      'category_id': categoryId,
    });
  }

  Future<void> deleteRule(String id) async {
    await _client.from('category_rules').delete().eq('id', id);
    _cache.removeFromCache('category_rules', id);
  }

  /// Soft-Delete (Tombstone); Buchungen behalten ihre (nun verwaiste) Referenz.
  Future<void> deleteCategory(String id) {
    return _client
        .from('categories')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
