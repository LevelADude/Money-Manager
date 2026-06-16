import 'app_transaction.dart' show TransactionDirection;

/// Art einer Kategorie – passt 1:1 zur Richtung einer Buchung.
enum CategoryKind { income, expense }

/// Eine Kategorie je Buch, siehe Tabelle `categories`.
class Category {
  const Category({
    required this.id,
    required this.ledgerId,
    required this.name,
    required this.kind,
  });

  final String id;
  final String ledgerId;
  final String name;
  final CategoryKind kind;

  /// Passt diese Kategorie zur gegebenen Buchungsrichtung?
  bool matches(TransactionDirection direction) =>
      (kind == CategoryKind.income) ==
      (direction == TransactionDirection.income);

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        ledgerId: json['ledger_id'] as String,
        name: json['name'] as String,
        kind: (json['kind'] as String) == 'income'
            ? CategoryKind.income
            : CategoryKind.expense,
      );
}
