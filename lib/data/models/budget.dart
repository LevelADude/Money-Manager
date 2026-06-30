/// Monatsbudget für eine Kategorie, siehe Tabelle `budgets`.
class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amountCents,
  });

  final String id;
  final String categoryId;
  final int amountCents;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    categoryId: json['category_id'] as String,
    amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
  );
}
