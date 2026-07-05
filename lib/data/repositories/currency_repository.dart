import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_currency.dart';

/// Zugriff auf die Tabelle `currencies` (eigene Währungen + Wechselkurse pro
/// Besitzer). RLS liefert eigene Zeilen plus die freigegebener Besitzer.
class CurrencyRepository {
  CurrencyRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<List<UserCurrency>> fetchAll() async {
    final rows = await _client.from('currencies').select();
    return (rows as List)
        .map((r) => UserCurrency.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Eigene Währung anlegen oder ihren Kurs setzen/ändern (Upsert auf
  /// (owner_id, code)). `rate` darf null sein (Währung ohne Kurs).
  Future<void> upsert(String code, double? rate) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('currencies').upsert({
      'owner_id': uid,
      'code': code.trim().toUpperCase(),
      'rate_to_base': rate,
    }, onConflict: 'owner_id,code');
  }

  /// Eigene Währung (samt Kurs) löschen.
  Future<void> remove(String code) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('currencies')
        .delete()
        .eq('owner_id', uid)
        .eq('code', code.trim().toUpperCase());
  }

  /// Eigene Basiswährung ins Profil schreiben, damit andere Nutzer die Kurse
  /// korrekt interpretieren können.
  Future<void> setMyBaseCurrency(String code) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('profiles')
        .update({'base_currency': code})
        .eq('id', uid);
  }
}
