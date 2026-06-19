import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/savings_goal.dart';

/// Zugriff auf die Tabelle `savings_goals` inkl. Stream + Offline-Cache.
class SavingsGoalRepository {
  SavingsGoalRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  Stream<List<SavingsGoal>> watchGoals() async* {
    final cached = _cache.readRows('savings_goals');
    if (cached.isNotEmpty) {
      yield cached.map(SavingsGoal.fromJson).toList();
    }
    try {
      yield* _client
          .from('savings_goals')
          .stream(primaryKey: ['id'])
          .order('created_at')
          .map((rows) {
        final unique = dedupRowsById(rows);
        _cache.writeRows('savings_goals', unique);
        return unique.map(SavingsGoal.fromJson).toList();
      });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  Future<void> upsertGoal({
    String? id,
    required String name,
    required int targetCents,
    DateTime? targetDate,
  }) {
    final data = {
      'name': name,
      'target_cents': targetCents,
      'target_date': targetDate?.toIso8601String().substring(0, 10),
    };
    if (id == null) {
      return _client.from('savings_goals').insert(data);
    }
    return _client.from('savings_goals').update(data).eq('id', id);
  }

  /// Erhöht/verringert den gesparten Betrag (Beitrag).
  Future<void> addContribution(String id, int currentSaved, int deltaCents) {
    final next = (currentSaved + deltaCents).clamp(0, 1 << 62);
    return _client
        .from('savings_goals')
        .update({'saved_cents': next}).eq('id', id);
  }

  Future<void> deleteGoal(String id) async {
    await _client.from('savings_goals').delete().eq('id', id);
    _cache.removeFromCache('savings_goals', id);
  }
}
