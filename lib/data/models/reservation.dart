import 'recurring_rule.dart' show IntervalUnit, intervalUnitFromDb, advanceDate;

/// Zurückgelegtes Geld auf einem Konto, siehe Tabelle `reservations`.
///
/// Der Kontostand bleibt unverändert; offene Reservierungen werden nur vom
/// „verfügbaren" Betrag abgezogen. Währung = Währung des Kontos. Cent.
class Reservation {
  const Reservation({
    required this.id,
    required this.accountId,
    required this.name,
    required this.amountCents,
    this.dueOn,
    this.categoryId,
    this.note = '',
    this.targetCents,
    this.topupCents,
    this.topupUnit,
    this.topupStart,
    this.topupCount = 0,
  });

  final String id;
  final String accountId;
  final String name;
  final int amountCents;

  /// Bis wann das Geld gebraucht wird (optional).
  final DateTime? dueOn;

  /// Kategorie, die beim Einlösen vorgeschlagen wird (optional).
  final String? categoryId;
  final String note;

  /// Deckel für wiederkehrende Rücklagen (optional).
  final int? targetCents;

  /// Wiederkehrende Rücklage: Betrag je [topupUnit] ab [topupStart].
  final int? topupCents;
  final IntervalUnit? topupUnit;
  final DateTime? topupStart;

  /// Bereits angewendete Aufstockungen.
  final int topupCount;

  bool get isRecurring =>
      topupCents != null && topupUnit != null && topupStart != null;

  /// Nächster Aufstockungs-Termin (null = nicht wiederkehrend oder Ziel
  /// erreicht).
  DateTime? get nextTopup {
    if (!isRecurring) return null;
    if (targetCents != null && amountCents >= targetCents!) return null;
    return advanceDate(
      topupStart!,
      topupUnit!,
      topupCount,
      anchorDay: topupStart!.day,
    );
  }

  /// Tage bis zur Fälligkeit (negativ = überfällig, null = kein Datum).
  int? daysUntilDue(DateTime today) {
    final d = dueOn;
    if (d == null) return null;
    final t = DateTime(today.year, today.month, today.day);
    return DateTime(d.year, d.month, d.day).difference(t).inDays;
  }

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
    id: json['id'] as String,
    accountId: json['account_id'] as String,
    name: (json['name'] as String?) ?? '',
    amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
    dueOn: _date(json['due_on']),
    categoryId: json['category_id'] as String?,
    note: (json['note'] as String?) ?? '',
    targetCents: (json['target_cents'] as num?)?.toInt(),
    topupCents: (json['topup_cents'] as num?)?.toInt(),
    topupUnit: json['topup_unit'] == null
        ? null
        : intervalUnitFromDb(json['topup_unit'] as String),
    topupStart: _date(json['topup_start']),
    topupCount: (json['topup_count'] as num?)?.toInt() ?? 0,
  );

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.parse(v as String);
}

/// Offene Reservierungen je Konto (Konto-ID -> Cent).
Map<String, int> reservedByAccount(Iterable<Reservation> reservations) {
  final out = <String, int>{};
  for (final r in reservations) {
    if (r.amountCents <= 0) continue;
    out[r.accountId] = (out[r.accountId] ?? 0) + r.amountCents;
  }
  return out;
}

/// Verfügbarer Saldo je Konto = Saldo - offene Reservierungen.
Map<String, int> availableBalances(
  Map<String, int> balances,
  Map<String, int> reserved,
) => {
  for (final e in balances.entries) e.key: e.value - (reserved[e.key] ?? 0),
};

/// Ist auf dem Konto mehr reserviert als vorhanden?
///
/// Vermögenskonten: verfügbarer Saldo < 0. Kreditkarten: nur mit Kreditrahmen,
/// wenn Rahmen + Saldo - Reserviert < 0. Kredite (und Karten ohne Rahmen)
/// werden nicht geprüft — dort ist ein negativer Saldo normal.
bool isOverReserved({
  required int balanceCents,
  required int reservedCents,
  required bool isLiability,
  int? creditLimitCents,
}) {
  if (reservedCents <= 0) return false;
  if (!isLiability) return balanceCents - reservedCents < 0;
  if (creditLimitCents == null) return false;
  return creditLimitCents + balanceCents - reservedCents < 0;
}
