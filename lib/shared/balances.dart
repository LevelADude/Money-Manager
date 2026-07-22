import '../data/models/account.dart';
import '../data/models/app_transaction.dart';

/// Zentrale Saldo-Berechnung, damit der Carry-over archivierter Jahre **überall**
/// konsistent eingerechnet wird. Buchungen archivierter Jahre sind aus der DB
/// entfernt; ihr Netto-Beitrag je Konto steckt im [carryover] (siehe
/// `archivedCarryoverProvider`), damit die Kontostände korrekt bleiben.

/// Saldo eines Kontos in Cent: Anfangssaldo + Carry-over + alle geladenen
/// Buchungen.
///
/// Achtung: laeuft einmal komplett ueber [txs]. Fuer MEHRERE Konten deshalb
/// nicht in einer Schleife aufrufen (das waere O(Konten x Buchungen)), sondern
/// [accountBalancesCents] nutzen — das erledigt alle Konten in einem Durchlauf.
int accountBalanceCents(
  Account account,
  Iterable<AppTransaction> txs,
  Map<String, int> carryover,
) {
  var sum = account.openingBalanceCents + (carryover[account.id] ?? 0);
  for (final t in txs) {
    sum += t.signedCentsFor(account.id);
  }
  return sum;
}

/// Salden ALLER [accounts] in **einem** Durchlauf durch [txs] (O(Konten +
/// Buchungen) statt O(Konten x Buchungen)).
///
/// Jede Buchung weiss selbst, welche Konten sie beruehrt (bei Uebertraegen
/// zwei), deshalb genuegt ein Durchlauf, der die Betraege direkt auf die
/// betroffenen Konten bucht. Das Ergebnis ist identisch zu
/// [accountBalanceCents] je Konto, nur eben ohne die Schleife pro Konto.
///
/// Konten ohne Buchungen sind enthalten (mit Anfangssaldo + Carry-over).
Map<String, int> accountBalancesCents(
  Iterable<Account> accounts,
  Iterable<AppTransaction> txs,
  Map<String, int> carryover,
) {
  final sums = <String, int>{
    for (final a in accounts)
      a.id: a.openingBalanceCents + (carryover[a.id] ?? 0),
  };
  for (final t in txs) {
    switch (t.type) {
      case TransactionType.income:
        final v = sums[t.accountId];
        if (v != null) sums[t.accountId] = v + t.amountCents;
      case TransactionType.expense:
        final v = sums[t.accountId];
        if (v != null) sums[t.accountId] = v - t.amountCents;
      case TransactionType.transfer:
        // Abgang beim Quellkonto, Zugang beim Zielkonto.
        final from = sums[t.accountId];
        if (from != null) sums[t.accountId] = from - t.amountCents;
        final toId = t.transferAccountId;
        if (toId != null) {
          final to = sums[toId];
          if (to != null) sums[toId] = to + t.amountCents;
        }
    }
  }
  return sums;
}

/// Wie [accountBalanceCents], aber nur Buchungen bis einschließlich [asOf]
/// (für Saldo-Verläufe). Der Carry-over zählt immer mit, da archivierte Jahre
/// vor dem Anzeigefenster liegen.
int accountBalanceAsOf(
  Account account,
  Iterable<AppTransaction> txs,
  Map<String, int> carryover,
  DateTime asOf,
) {
  var sum = account.openingBalanceCents + (carryover[account.id] ?? 0);
  for (final t in txs) {
    if (!t.occurredOn.isAfter(asOf)) sum += t.signedCentsFor(account.id);
  }
  return sum;
}
