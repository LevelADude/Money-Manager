import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/category.dart';
import '../models/category_pref.dart';
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
        return c != 0
            ? c
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  Stream<List<Category>> watchCategories() async* {
    final cached = _cache.readRows('categories');
    if (cached.isNotEmpty) {
      yield _sorted(
        cached.where((r) => r['deleted_at'] == null).map(Category.fromJson),
      );
    }
    try {
      yield* _client
          .from('categories')
          .stream(primaryKey: ['id'])
          .order('sort_order')
          .map((rows) {
            final unique = dedupRowsById(rows);
            _cache.writeRows('categories', unique);
            return _sorted(
              unique
                  .where((r) => r['deleted_at'] == null)
                  .map(Category.fromJson),
            );
          });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  // ----- Persönliche Overlay-Einstellungen (category_prefs) -----
  //
  // Reihenfolge / aktiv / ausgeblendet werden PRO NUTZER gespeichert, damit
  // jeder auch die (gruppenweiten) Preset-Kategorien für sich anpassen kann,
  // ohne andere zu beeinflussen. Siehe Migration 0036.

  String? get _uid => _client.auth.currentUser?.id;

  /// Live-Map der eigenen Overlays (Kategorie-ID -> [CategoryPref]).
  Stream<Map<String, CategoryPref>> watchMyPrefs() async* {
    Map<String, CategoryPref> toMap(List<Map<String, dynamic>> rows) => {
      for (final r in rows)
        r['category_id'] as String: CategoryPref.fromJson(r),
    };
    final cached = _cache.readRows('category_prefs');
    if (cached.isNotEmpty) yield toMap(cached);
    try {
      yield* _client
          .from('category_prefs')
          .stream(primaryKey: ['owner_id', 'category_id'])
          .map((rows) {
            _cache.writeRows('category_prefs', rows);
            return toMap(rows);
          });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  /// Speichert eine neue Reihenfolge als persönliches Overlay
  /// (Kategorie-ID -> sort_order).
  Future<void> reorder(List<({String id, int sortOrder})> orders) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('category_prefs').upsert([
      for (final o in orders)
        {'owner_id': uid, 'category_id': o.id, 'sort_order': o.sortOrder},
    ], onConflict: 'owner_id,category_id');
  }

  /// Persönliches Aktiv/Inaktiv-Overlay.
  Future<void> setActive({required String id, required bool active}) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('category_prefs').upsert({
      'owner_id': uid,
      'category_id': id,
      'active': active,
    }, onConflict: 'owner_id,category_id');
  }

  /// Blendet eine Kategorie für den aktuellen Nutzer aus bzw. wieder ein.
  /// So lassen sich auch Preset-Kategorien „löschen" (nur für sich).
  Future<void> setHidden({required String id, required bool hidden}) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('category_prefs').upsert({
      'owner_id': uid,
      'category_id': id,
      'hidden': hidden,
    }, onConflict: 'owner_id,category_id');
  }

  Future<void> addCategory({
    required String name,
    required CategoryKind kind,
    String? icon,
    String? emoji,
  }) {
    return _client.from('categories').insert({
      'name': name,
      'kind': categoryKindToDb(kind),
      'icon': icon,
      'emoji': emoji,
      'is_preset': false,
    });
  }

  /// Sentinel: „Feld nicht ändern" (zur Unterscheidung von „auf null setzen").
  static const _keep = Object();

  /// Ändert Name, Icon, Emoji und/oder Art einer (eigenen) Kategorie.
  /// [emoji] = `_keep` lässt das Feld unverändert; explizit `null` entfernt es.
  Future<void> updateCategory({
    required String id,
    String? name,
    String? icon,
    CategoryKind? kind,
    Object? emoji = _keep,
  }) {
    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (icon != null) patch['icon'] = icon;
    if (kind != null) patch['kind'] = categoryKindToDb(kind);
    if (!identical(emoji, _keep)) patch['emoji'] = emoji as String?;
    if (patch.isEmpty) return Future.value();
    return _client.from('categories').update(patch).eq('id', id);
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
            final unique = dedupRowsById(rows);
            _cache.writeRows('category_rules', unique);
            return unique.map(CategoryRule.fromJson).toList();
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
