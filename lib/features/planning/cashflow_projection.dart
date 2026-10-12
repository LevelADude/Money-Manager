import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/recurring_rule.dart';
import '../../data/models/reservation.dart';

/// Ein geplanter Zu-/Abfluss im Cashflow (Betrag in Hauptwährung).
typedef CashflowEvent = ({
  DateTime date,
  String title,
  int signed,
  bool isReservation,
});

/// Ergebnis der Prognose: aktueller Stand + chronologische Ereignisse
/// (alles in Hauptwährung).
typedef CashflowProjection = ({int current, List<CashflowEvent> events});

/// Prognostiziert den Kontostand über [horizon] anhand der Daueraufträge und
/// fälliger Reservierungen.
///
/// Berücksichtigt werden nur [accounts], die ins Vermögen zählen und nicht
/// archiviert sind; alle Beträge werden per [convert] in die Hauptwährung
/// umgerechnet (sonst würden z. B. Rupien als Euro addiert). Überträge zählen,
/// wenn genau eine Seite im Umfang liegt (Geld verlässt/erreicht den Umfang);
/// liegen beide Seiten darin, heben sie sich auf.
CashflowProjection projectCashflow({
  required Iterable<Account> accounts,
  required Map<String, int> balances,
  required Iterable<RecurringRule> rules,
  required Iterable<Reservation> reservations,
  required int Function(int cents, String currency) convert,
  required DateTime today,
  required DateTime horizon,
  required String Function(RecurringRule rule) ruleTitle,
  required String Function(Reservation reservation) reservationTitle,
}) {
  final inScope = <String, Account>{
    for (final a in accounts)
      if (a.includeInNetWorth && !a.archived) a.id: a,
  };

  var current = 0;
  for (final a in inScope.values) {
    current += convert(balances[a.id] ?? 0, a.currency);
  }

  final events = <CashflowEvent>[];
  for (final r in rules) {
    if (!r.active) continue;
    final from = inScope[r.accountId];
    final to = r.transferAccountId == null
        ? null
        : inScope[r.transferAccountId];
    final int signed = switch (r.type) {
      TransactionType.income when from != null => convert(
        r.amountCents,
        from.currency,
      ),
      TransactionType.expense when from != null => -convert(
        r.amountCents,
        from.currency,
      ),
      TransactionType.transfer when from != null && to == null => -convert(
        r.amountCents,
        from.currency,
      ),
      // Zugang von außerhalb: Betrag liegt in der Währung des Quellkontos,
      // das nicht im Umfang ist — dann mit der Zielwährung umrechnen.
      TransactionType.transfer when from == null && to != null => convert(
        r.amountCents,
        to.currency,
      ),
      _ => 0,
    };
    if (signed == 0) continue;

    final count = r.intervalCount < 1 ? 1 : r.intervalCount;
    var d = r.nextDue;
    var guard = 0;
    while (d.isBefore(today) && guard < 1000) {
      d = advanceDate(d, r.intervalUnit, count, anchorDay: r.anchorDay);
      guard++;
    }
    while (!d.isAfter(horizon) &&
        (r.endDate == null || !d.isAfter(r.endDate!)) &&
        guard < 1000) {
      events.add((
        date: d,
        title: ruleTitle(r),
        signed: signed,
        isReservation: false,
      ));
      d = advanceDate(d, r.intervalUnit, count, anchorDay: r.anchorDay);
      guard++;
    }
  }

  // Reservierungen mit Fälligkeit als geplante Abflüsse (überfällige heute).
  for (final r in reservations) {
    final due = r.dueOn;
    final a = inScope[r.accountId];
    if (a == null || due == null || r.amountCents <= 0) continue;
    if (due.isAfter(horizon)) continue;
    events.add((
      date: due.isBefore(today) ? today : due,
      title: reservationTitle(r),
      signed: -convert(r.amountCents, a.currency),
      isReservation: true,
    ));
  }

  events.sort((a, b) => a.date.compareTo(b.date));
  return (current: current, events: events);
}
