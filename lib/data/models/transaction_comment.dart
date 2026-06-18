/// Ein Kommentar an einer Buchung.
class TransactionComment {
  const TransactionComment({
    required this.id,
    required this.transactionId,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String transactionId;
  final String? author;
  final String body;
  final DateTime createdAt;

  factory TransactionComment.fromJson(Map<String, dynamic> json) =>
      TransactionComment(
        id: json['id'] as String,
        transactionId: json['transaction_id'] as String,
        author: json['author'] as String?,
        body: (json['body'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
