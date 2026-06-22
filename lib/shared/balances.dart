import '../data/models/account.dart';
import '../data/models/app_transaction.dart';

/// Zentrale Saldo-Berechnung, damit der Carry-over archivierter Jahre **überall**
/// konsistent eingerechnet wird. Buchungen archivierter Jahre sind aus der DB
/// entfernt; ihr Netto-Beitrag je Konto steckt im [carryover] (siehe
/// `archivedCarryoverProvider`), damit die Kontostände korrekt bleiben.

/// Saldo eines Kontos in Cent: Anfangssaldo + Carry-over + alle geladenen
/// Buchungen.
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
