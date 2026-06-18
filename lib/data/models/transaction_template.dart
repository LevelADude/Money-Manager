import 'app_transaction.dart' show TransactionType, transactionTypeFromDb;

/// Eine wiederverwendbare Buchungs-Vorlage (Favorit). Beträge in Cent.
class TransactionTemplate {
  const TransactionTemplate({
    required this.id,
    required this.name,
    required this.accountId,
    required this.type,
    required this.amountCents,
    required this.categoryId,
    required this.title,
    required this.note,
    required this.tags,
  });

  final String id;
  final String name;
  final String? accountId;
  final TransactionType type;
  final int amountCents;
  final String? categoryId;
  final String title;
  final String note;
  final List<String> tags;

  factory TransactionTemplate.fromJson(Map<String, dynamic> json) =>
      TransactionTemplate(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        accountId: json['account_id'] as String?,
        type: transactionTypeFromDb((json['type'] as String?) ?? 'expense'),
        amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
        categoryId: json['category_id'] as String?,
        title: (json['title'] as String?) ?? '',
        note: (json['note'] as String?) ?? '',
        tags: (json['tags'] is List)
            ? (json['tags'] as List).map((e) => e.toString()).toList()
            : const [],
      );
}
