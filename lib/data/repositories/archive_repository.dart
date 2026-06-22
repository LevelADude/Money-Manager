import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_cache.dart';
import '../models/account.dart';
import '../models/app_transaction.dart';
import '../models/archive_config_status.dart';
import '../models/archived_year.dart';
import 'receipt_storage.dart';

/// Archivierung alter Jahre nach GitHub (verschlüsselt via Edge Function
/// `archive-proxy`). Liest ein Jahr aus Supabase, lagert es aus, schreibt den
/// Marker (+ Carry-over je Konto) und löscht die Daten danach endgültig, um
/// DB-/Storage-Speicher freizugeben. De-Archivieren holt ein Jahr zurück.
class ArchiveRepository {
  ArchiveRepository(this._client, this._cache, this._receipts);

  final SupabaseClient _client;
  final AppCache _cache;
  final ReceiptStorage _receipts;

  static const _table = 'archived_years';

  // --- Archiv-Repo-Konfiguration (serverseitig) -----------------------

  /// Status der Archiv-Repo-Verbindung (ohne Geheimnisse).
  Future<ArchiveConfigStatus> archiveConfigStatus() async {
    final rows = await _client.rpc('get_archive_config_status');
    if (rows is List && rows.isNotEmpty) {
      return ArchiveConfigStatus.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
    }
    return ArchiveConfigStatus.empty;
  }

  /// Setzt/ändert Repo (+ optional Token/Schlüssel). Leere Felder lassen den
  /// bisherigen Wert stehen. Nur Admins (serverseitig erzwungen).
  Future<void> setArchiveConfig({
    required String repo,
    String? token,
    String? encKey,
  }) {
    return _client.rpc(
      'set_archive_config',
      params: {
        'p_repo': normalizeRepo(repo),
        'p_token': token ?? '',
        'p_enc_key': encKey ?? '',
      },
    );
  }

  Future<void> clearArchiveConfig() => _client.rpc('clear_archive_config');

  /// Zufälliger AES-256-Schlüssel als Base64 (32 Byte).
  static String generateEncKey() {
    final rnd = Random.secure();
    return base64Encode(List<int>.generate(32, (_) => rnd.nextInt(256)));
  }

  /// Normalisiert eine Repo-Angabe auf "owner/name" (akzeptiert auch volle
  /// GitHub-URLs bzw. SSH-Form, mit/ohne .git).
  static String normalizeRepo(String input) {
    var s = input.trim();
    s = s.replaceFirst(
      RegExp(r'^https?://github\.com/', caseSensitive: false),
      '',
    );
    s = s.replaceFirst(RegExp(r'^git@github\.com:', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'\.git$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'/+$'), '');
    return s;
  }

  /// Cache-then-Stream der archivierten Jahre (Marker + Carry-over für Salden).
  Stream<List<ArchivedYear>> watchArchivedYears() async* {
    final cached = _cache.readRows(_table);
    if (cached.isNotEmpty) {
      yield cached.map(ArchivedYear.fromJson).toList();
    }
    try {
      yield* _client
          .from(_table)
          .stream(primaryKey: ['year'])
          .order('year')
          .map((rows) {
            _cache.writeRows(_table, rows);
            return rows.map(ArchivedYear.fromJson).toList();
          });
    } catch (_) {
      // offline: beim Cache bleiben.
    }
  }

  // --- Archivieren ----------------------------------------------------

  /// Lagert ein Jahr aus: serialisiert + verschlüsselt nach GitHub, schreibt
  /// den Marker (+ Carry-over) und löscht die Daten danach endgültig.
  /// [accounts] dient der Carry-over-Berechnung je Konto.
  Future<ArchivedYear> archiveYear({
    required int year,
    required List<Account> accounts,
    String? exportedAtIso,
    void Function(String step)? onProgress,
  }) async {
    onProgress?.call('read');
    final txRows = await _rawTransactionsForYear(year);
    final txIds = [for (final r in txRows) r['id'] as String];
    final splitRows = await _rawChildren('transaction_splits', txIds);
    final commentRows = await _rawChildren('transaction_comments', txIds);

    // Belege herunterladen (nur vorhandene Pfade).
    onProgress?.call('receipts');
    final receiptPaths = <String>[
      for (final r in txRows)
        if ((r['receipt_path'] as String?)?.isNotEmpty ?? false)
          r['receipt_path'] as String,
    ];
    final receipts = <String, Map<String, String>>{};
    for (final path in receiptPaths) {
      try {
        final bytes = await _receipts.download(path);
        receipts[path] = {'ext': _extOf(path), 'b64': base64Encode(bytes)};
      } catch (_) {
        // Beleg nicht ladbar -> überspringen (Buchungsdaten bleiben erhalten).
      }
    }

    // Carry-over je Konto aus den NICHT gelöschten Buchungen (nur diese zählen
    // zum Saldo; Soft-Deletes haben nie beigetragen).
    final liveTxs = [
      for (final r in txRows)
        if (r['deleted_at'] == null) AppTransaction.fromJson(r),
    ];
    final carryover = <String, int>{};
    for (final a in accounts) {
      var sum = 0;
      for (final t in liveTxs) {
        sum += t.signedCentsFor(a.id);
      }
      if (sum != 0) carryover[a.id] = sum;
    }

    // Verschlüsselt nach GitHub schreiben.
    onProgress?.call('upload');
    final payload = <String, dynamic>{
      'app': 'money-manager',
      'kind': 'archive-year',
      'version': 1,
      'year': year,
      'exported_at': exportedAtIso ?? DateTime.now().toUtc().toIso8601String(),
      'transactions': txRows,
      'splits': splitRows,
      'comments': commentRows,
      'receipts': receipts,
    };
    final writeRes = await _invoke({
      'action': 'write',
      'year': year,
      'payload': payload,
    });
    final githubPath = writeRes['path'] as String?;
    final byteSize = (writeRes['size'] as num?)?.toInt() ?? 0;

    // Marker + Carry-over speichern (RLS: nur Admin).
    onProgress?.call('mark');
    await _client.from(_table).upsert({
      'year': year,
      'tx_count': txRows.length,
      'byte_size': byteSize,
      'carryover_by_account': carryover,
      'github_path': githubPath,
      'archived_at': DateTime.now().toUtc().toIso8601String(),
    });

    // Belege aus dem Storage entfernen (gibt den meisten Speicher frei) …
    onProgress?.call('purge');
    await _receipts.deleteMany(receiptPaths);
    // … und die Buchungen endgültig löschen (Splits/Kommentare via Cascade).
    await _client.rpc('purge_year_data', params: {'p_year': year});

    // Lokalen Cache der gelöschten Buchungen bereinigen.
    for (final id in txIds) {
      _cache.removeFromCache('transactions', id);
    }

    return ArchivedYear(
      year: year,
      archivedAt: DateTime.now(),
      txCount: txRows.length,
      byteSize: byteSize,
      carryoverByAccount: carryover,
    );
  }

  // --- Lesen / De-Archivieren ----------------------------------------

  /// Lädt das Roh-Payload eines archivierten Jahres (für die read-only-Ansicht).
  Future<Map<String, dynamic>> loadArchivedYear(int year) async {
    final res = await _invoke({'action': 'read', 'year': year});
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  /// Holt ein Jahr zurück in die DB (Sicherheitsnetz). Fügt Buchungen, Splits,
  /// Kommentare und Belege wieder ein und entfernt Marker + GitHub-Datei.
  Future<void> deArchiveYear(int year) async {
    final data = await loadArchivedYear(year);
    final txRows = _rowsOf(data['transactions']);
    final splitRows = _rowsOf(data['splits']);
    final commentRows = _rowsOf(data['comments']);
    final receipts =
        (data['receipts'] as Map?)?.cast<String, dynamic>() ?? const {};

    // Belege wieder hochladen; alte -> neue Pfade abbilden.
    final pathMap = <String, String>{};
    for (final entry in receipts.entries) {
      final info = Map<String, dynamic>.from(entry.value as Map);
      final bytes = base64Decode(info['b64'] as String);
      final ext = (info['ext'] as String?) ?? 'jpg';
      pathMap[entry.key] = await _receipts.upload(bytes, ext);
    }
    for (final r in txRows) {
      final old = r['receipt_path'] as String?;
      if (old != null && pathMap.containsKey(old)) {
        r['receipt_path'] = pathMap[old];
      }
    }

    if (txRows.isNotEmpty) await _client.from('transactions').upsert(txRows);
    if (splitRows.isNotEmpty) {
      await _client.from('transaction_splits').upsert(splitRows);
    }
    if (commentRows.isNotEmpty) {
      await _client.from('transaction_comments').upsert(commentRows);
    }

    // Marker entfernen + GitHub-Datei löschen.
    await _client.from(_table).delete().eq('year', year);
    await _invoke({'action': 'delete', 'year': year});
  }

  // --- Hilfen ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> _rawTransactionsForYear(int year) async {
    final rows = await _client
        .from('transactions')
        .select()
        .gte('occurred_on', '$year-01-01')
        .lte('occurred_on', '$year-12-31');
    return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
  }

  Future<List<Map<String, dynamic>>> _rawChildren(
    String table,
    List<String> txIds,
  ) async {
    if (txIds.isEmpty) return const [];
    final out = <Map<String, dynamic>>[];
    const chunk = 200;
    for (var i = 0; i < txIds.length; i += chunk) {
      final end = (i + chunk) < txIds.length ? i + chunk : txIds.length;
      final rows = await _client
          .from(table)
          .select()
          .inFilter('transaction_id', txIds.sublist(i, end));
      for (final r in rows as List) {
        out.add(Map<String, dynamic>.from(r as Map));
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _rowsOf(dynamic raw) => [
    for (final r in (raw as List? ?? const []))
      Map<String, dynamic>.from(r as Map),
  ];

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final res = await _client.functions.invoke('archive-proxy', body: body);
    if (res.status != 200) {
      final data = res.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Fehler ${res.status}';
      throw Exception(msg);
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot + 1) : 'jpg';
  }
}
