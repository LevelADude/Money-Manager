import 'app_transaction.dart' show TransactionType, transactionTypeFromDb;

/// Intervall-Einheit für Daueraufträge.
enum IntervalUnit { day, week, month, year }

IntervalUnit intervalUnitFromDb(String s) => switch (s) {
  'day' => IntervalUnit.day,
  'week' => IntervalUnit.week,
  'year' => IntervalUnit.year,
  _ => IntervalUnit.month,
};

String intervalUnitToDb(IntervalUnit u) => switch (u) {
  IntervalUnit.day => 'day',
  IntervalUnit.week => 'week',
  IntervalUnit.month => 'month',
  IntervalUnit.year => 'year',
};

extension IntervalUnitX on IntervalUnit {
  String get label => switch (this) {
    IntervalUnit.day => 'Tag(e)',
    IntervalUnit.week => 'Woche(n)',
    IntervalUnit.month => 'Monat(e)',
    IntervalUnit.year => 'Jahr(e)',
  };
}

/// Nächstes Fälligkeitsdatum nach `count` Einheiten.
///
/// Für Monats-/Jahresschritte wird vom festen [anchorDay] (dem Soll-Tag der
/// Regel, 1–31) ausgegangen und nur auf das Monatsende geklemmt. So driftet eine
/// 31.-Regel nicht nach unten (31→28→31 statt 31→28→28) UND eine echte 28.-Regel
/// wird nie auf das Monatsende befördert. Ohne [anchorDay] gilt der Tag von [d]
/// als Anker (für Einmal-Vorschläge ohne gespeicherte Regel).
DateTime advanceDate(
  DateTime d,
  IntervalUnit unit,
  int count, {
  int? anchorDay,
}) {
  switch (unit) {
    case IntervalUnit.day:
      return DateTime(d.year, d.month, d.day + count);
    case IntervalUnit.week:
      return DateTime(d.year, d.month, d.day + 7 * count);
    case IntervalUnit.month:
      return _addMonths(d, count, anchorDay ?? d.day);
    case IntervalUnit.year:
      return _addMonths(d, 12 * count, anchorDay ?? d.day);
  }
}

DateTime _addMonths(DateTime d, int months, int anchorDay) {
  final total = (d.month - 1) + months;
  final year = d.year + (total ~/ 12);
  final month = (total % 12) + 1;
  final lastDay = DateTime(
    year,
    month + 1,
    0,
  ).day; // letzter Tag des Zielmonats
  final day = anchorDay < lastDay ? anchorDay : lastDay;
  return DateTime(year, month, day);
}

/// Eine Dauerauftrags-Regel, siehe Tabelle `recurring_rules`.
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amountCents,
    required this.categoryId,
    required this.transferAccountId,
    required this.title,
    required this.note,
    required this.intervalUnit,
    required this.intervalCount,
    required this.nextDue,
    required this.endDate,
    required this.active,
    required this.anchorDay,
  });

  final String id;
  final String accountId;
  final TransactionType type;
  final int amountCents;
  final String? categoryId;
  final String? transferAccountId;
  final String title;
  final String note;
  final IntervalUnit intervalUnit;
  final int intervalCount;
  final DateTime nextDue;
  final DateTime? endDate;
  final bool active;

  /// Soll-Tag des Monats (1–31) für Monats-/Jahresregeln. Bleibt fest, damit das
  /// Datum nicht über die Monate driftet. Siehe [advanceDate].
  final int anchorDay;

  factory RecurringRule.fromJson(Map<String, dynamic> json) => RecurringRule(
    id: json['id'] as String,
    accountId: json['account_id'] as String,
    type: transactionTypeFromDb((json['type'] as String?) ?? 'expense'),
    amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
    categoryId: json['category_id'] as String?,
    transferAccountId: json['transfer_account_id'] as String?,
    title: (json['title'] as String?) ?? '',
    note: (json['note'] as String?) ?? '',
    intervalUnit: intervalUnitFromDb(
      (json['interval_unit'] as String?) ?? 'month',
    ),
    intervalCount: (json['interval_count'] as num?)?.toInt() ?? 1,
    nextDue: DateTime.parse(json['next_due'] as String),
    endDate: json['end_date'] == null
        ? null
        : DateTime.parse(json['end_date'] as String),
    active: (json['active'] as bool?) ?? true,
    anchorDay:
        (json['anchor_day'] as num?)?.toInt() ??
        DateTime.parse(json['next_due'] as String).day,
  );
}
