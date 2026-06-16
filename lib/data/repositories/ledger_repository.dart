import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ledger.dart';

/// Zugriff auf die Tabelle `ledgers` inkl. Realtime-Stream.
class LedgerRepository {
  LedgerRepository(this._client);

  final SupabaseClient _client;

  /// Live-Stream aller Bücher (synchronisiert sich automatisch über Geräte).
  Stream<List<Ledger>> watchLedgers() {
    return _client
        .from('ledgers')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(Ledger.fromJson).toList());
  }

  Future<void> createLedger({required String name, String currency = 'EUR'}) {
    return _client.from('ledgers').insert({
      'name': name,
      'currency': currency,
    });
  }

  Future<void> renameLedger({required String id, required String name}) {
    return _client.from('ledgers').update({'name': name}).eq('id', id);
  }

  Future<void> deleteLedger(String id) {
    return _client.from('ledgers').delete().eq('id', id);
  }
}
