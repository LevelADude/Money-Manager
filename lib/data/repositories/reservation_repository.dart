import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/recurring_rule.dart' show IntervalUnit, intervalUnitToDb;
import '../models/reservation.dart';

/// Zugriff auf die Tabelle `reservations` inkl. Stream + Offline-Cache.
class ReservationRepository {
  ReservationRepository(this._client, this._cache);

  final SupabaseClient _client;
  final AppCache _cache;

  static String? _d(DateTime? d) => d?.toIso8601String().substring(0, 10);

  Stream<List<Reservation>> watchReservations() async* {
    final cached = _cache.readRows('reservations');
    if (cached.isNotEmpty) {
      yield cached.map(Reservation.fromJson).toList();
    }
    try {
      yield* _client
          .from('reservations')
          .stream(primaryKey: ['id'])
          .order('created_at')
          .map((rows) {
            final unique = dedupRowsById(rows);
            _cache.writeRows('reservations', unique);
            return unique.map(Reservation.fromJson).toList();
          });
    } catch (_) {
      // Offline: beim Cache bleiben.
    }
  }

  /// Legt eine Reservierung an (ohne [id]) oder ändert sie.
  ///
  /// Wiederkehrend nur, wenn [topupCents], [topupUnit] und [topupStart]
  /// gesetzt sind. Wird der Rhythmus geändert, beginnt die Zählung neu
  /// ([topupCount] = 0), sonst würden alte Termine mit neuem Start verrechnet.
  Future<void> upsert({
    String? id,
    required String accountId,
    required String name,
    required int amountCents,
    DateTime? dueOn,
    String? categoryId,
    String note = '',
    int? targetCents,
    int? topupCents,
    IntervalUnit? topupUnit,
    DateTime? topupStart,
    bool resetTopupCount = true,
  }) {
    final recurring =
        topupCents != null && topupUnit != null && topupStart != null;
    final data = <String, dynamic>{
      'account_id': accountId,
      'name': name,
      'amount_cents': amountCents,
      'due_on': _d(dueOn),
      'category_id': categoryId,
      'note': note,
      'target_cents': recurring ? targetCents : null,
      'topup_cents': recurring ? topupCents : null,
      'topup_unit': recurring ? intervalUnitToDb(topupUnit) : null,
      'topup_start': recurring ? _d(topupStart) : null,
      if (resetTopupCount) 'topup_count': 0,
    };
    if (id == null) {
      return _client.from('reservations').insert(data);
    }
    return _client.from('reservations').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('reservations').delete().eq('id', id);
    _cache.removeFromCache('reservations', id);
  }

  /// Löst eine Reservierung ein: legt die Ausgabe an und verringert/entfernt
  /// die Reservierung atomar (RPC `redeem_reservation`). Gibt die ID der
  /// neuen Buchung zurück.
  Future<String> redeem({
    required String id,
    required int amountCents,
    required DateTime occurredOn,
    required String title,
    String? categoryId,
    String note = '',
    required bool keepRest,
    DateTime? dueOn,
  }) async {
    final txId = await _client.rpc(
      'redeem_reservation',
      params: {
        'p_id': id,
        'p_amount': amountCents,
        'p_occurred_on': _d(occurredOn),
        'p_title': title,
        'p_category_id': categoryId,
        'p_note': note,
        'p_keep_rest': keepRest,
        'p_due_on': _d(dueOn),
      },
    );
    return txId as String;
  }

  /// Schreibt fällige wiederkehrende Rücklagen fort (RPC, race-sicher).
  /// Liefert die Zahl der angewendeten Termine; offline 0.
  Future<int> applyTopups() async {
    try {
      final n = await _client.rpc('apply_reservation_topups');
      return (n as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
