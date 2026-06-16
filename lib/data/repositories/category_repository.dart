import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';

/// Zugriff auf die Tabelle `categories` inkl. Realtime-Stream.
class CategoryRepository {
  CategoryRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Category>> watchCategories(String ledgerId) {
    return _client
        .from('categories')
        .stream(primaryKey: ['id'])
        .eq('ledger_id', ledgerId)
        .order('name')
        .map((rows) => rows.map(Category.fromJson).toList());
  }

  Future<void> addCategory({
    required String ledgerId,
    required String name,
    required CategoryKind kind,
  }) {
    return _client.from('categories').insert({
      'ledger_id': ledgerId,
      'name': name,
      'kind': kind == CategoryKind.income ? 'income' : 'expense',
    });
  }

  Future<void> deleteCategory(String id) {
    return _client.from('categories').delete().eq('id', id);
  }
}
