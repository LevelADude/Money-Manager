/// Art einer Buchung. `transfer` verschiebt Geld zwischen zwei eigenen Konten
/// und zählt nicht als Einnahme/Ausgabe.
enum TransactionType { expense, income, transfer }

TransactionType transactionTypeFromDb(String s) => switch (s) {
      'income' => TransactionType.income,
      'transfer' => TransactionType.transfer,
      _ => TransactionType.expense,
    };

String transactionTypeToDb(TransactionType t) => switch (t) {
      TransactionType.income => 'income',
      TransactionType.transfer => 'transfer',
      TransactionType.expense => 'expense',
    };

extension TransactionTypeX on TransactionType {
  String get label => switch (this) {
        TransactionType.income => 'Einnahme',
        TransactionType.transfer => 'Übertrag',
        TransactionType.expense => 'Ausgabe',
      };
}

/// Eine Buchung, siehe Tabelle `transactions`. Beträge in Cent.
class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amountCents,
    required this.occurredOn,
    required this.categoryId,
    required this.transferAccountId,
    required this.title,
    required this.note,
    required this.createdBy,
    required this.receiptPath,
    this.tags = const [],
  });

  final String id;
  final String accountId;
  final TransactionType type;
  final int amountCents;
  final DateTime occurredOn;
  final String? categoryId;
  final String? transferAccountId;
  final String title;
  final String note;
  final String? createdBy;
  final String? receiptPath;
  final List<String> tags;

  /// Vorzeichenbehafteter Betrag aus Sicht eines bestimmten Kontos.
  /// WICHTIG: zählt nur für das Konto, zu dem die Buchung gehört (bzw. das
  /// Übertrags-Zielkonto). Sonst 0 — sonst würde jede Buchung jedes Konto
  /// beeinflussen.
  int signedCentsFor(String accountId) {
    switch (type) {
      case TransactionType.income:
        return this.accountId == accountId ? amountCents : 0;
      case TransactionType.expense:
        return this.accountId == accountId ? -amountCents : 0;
      case TransactionType.transfer:
        if (this.accountId == accountId) return -amountCents; // Abgang
        if (transferAccountId == accountId) return amountCents; // Zugang
        return 0;
    }
  }

  factory AppTransaction.fromJson(Map<String, dynamic> json) => AppTransaction(
        id: json['id'] as String,
        accountId: json['account_id'] as String,
        type: transactionTypeFromDb((json['type'] as String?) ?? 'expense'),
        amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
        occurredOn: DateTime.parse(json['occurred_on'] as String),
        categoryId: json['category_id'] as String?,
        transferAccountId: json['transfer_account_id'] as String?,
        title: (json['title'] as String?) ?? '',
        note: (json['note'] as String?) ?? '',
        createdBy: json['created_by'] as String?,
        receiptPath: json['receipt_path'] as String?,
        tags: _parseTags(json['tags']),
      );

  static List<String> _parseTags(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    // Postgres-Array kann als String "{a,b}" über manche Pfade kommen.
    if (raw is String && raw.startsWith('{') && raw.endsWith('}')) {
      final inner = raw.substring(1, raw.length - 1);
      if (inner.isEmpty) return const [];
      return inner
          .split(',')
          .map((s) => s.replaceAll('"', '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
