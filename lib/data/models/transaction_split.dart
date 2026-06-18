/// Eine Aufteilung (Split) einer Buchung auf eine Kategorie. Beträge in Cent.
/// Die Summe aller Splits einer Buchung entspricht dem Buchungsbetrag.
class TransactionSplit {
  const TransactionSplit({
    required this.id,
    required this.transactionId,
    required this.categoryId,
    required this.amountCents,
    required this.note,
  });

  final String id;
  final String transactionId;
  final String? categoryId;
  final int amountCents;
  final String note;

  factory TransactionSplit.fromJson(Map<String, dynamic> json) =>
      TransactionSplit(
        id: json['id'] as String,
        transactionId: json['transaction_id'] as String,
        categoryId: json['category_id'] as String?,
        amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
        note: (json['note'] as String?) ?? '',
      );
}
