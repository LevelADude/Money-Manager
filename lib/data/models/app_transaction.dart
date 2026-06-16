/// Richtung einer Buchung.
enum TransactionDirection { income, expense }

/// Eine Buchung, siehe Tabelle `transactions`.
///
/// `AppTransaction` statt `Transaction`, um Namenskollisionen mit
/// Datenbank-/SDK-Typen zu vermeiden.
class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.ledgerId,
    required this.categoryId,
    required this.occurredOn,
    required this.direction,
    required this.amount,
    required this.note,
    required this.createdBy,
  });

  final String id;
  final String ledgerId;
  final String? categoryId;
  final DateTime occurredOn;
  final TransactionDirection direction;
  final double amount;
  final String note;
  final String? createdBy;

  /// Vorzeichenbehafteter Betrag: Einnahmen positiv, Ausgaben negativ.
  double get signedAmount =>
      direction == TransactionDirection.income ? amount : -amount;

  factory AppTransaction.fromJson(Map<String, dynamic> json) => AppTransaction(
        id: json['id'] as String,
        ledgerId: json['ledger_id'] as String,
        categoryId: json['category_id'] as String?,
        occurredOn: DateTime.parse(json['occurred_on'] as String),
        direction: (json['direction'] as String) == 'income'
            ? TransactionDirection.income
            : TransactionDirection.expense,
        amount: (json['amount'] as num).toDouble(),
        note: (json['note'] as String?) ?? '',
        createdBy: json['created_by'] as String?,
      );
}
