/// Ein nach GitHub ausgelagertes Jahr (Tabelle `archived_years`). Marker plus
/// Carry-over: pro Konto die Netto-Summe (Cent) der ausgelagerten Buchungen,
/// damit die laufenden Kontostände nach dem Löschen korrekt bleiben.
class ArchivedYear {
  const ArchivedYear({
    required this.year,
    required this.archivedAt,
    required this.txCount,
    required this.byteSize,
    required this.carryoverByAccount,
  });

  final int year;
  final DateTime? archivedAt;
  final int txCount;
  final int byteSize;
  final Map<String, int> carryoverByAccount;

  factory ArchivedYear.fromJson(Map<String, dynamic> json) => ArchivedYear(
        year: (json['year'] as num).toInt(),
        archivedAt: json['archived_at'] == null
            ? null
            : DateTime.tryParse(json['archived_at'] as String),
        txCount: (json['tx_count'] as num?)?.toInt() ?? 0,
        byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
        carryoverByAccount: _parseCarryover(json['carryover_by_account']),
      );

  static Map<String, int> _parseCarryover(dynamic raw) {
    if (raw is Map) {
      return raw.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
      );
    }
    return const {};
  }
}
