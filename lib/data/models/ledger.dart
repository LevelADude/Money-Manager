/// Ein Buch (getrennte Buchhaltung), siehe Tabelle `ledgers`.
class Ledger {
  const Ledger({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.currency,
    required this.archived,
  });

  final String id;
  final String name;
  final String? ownerId;
  final String currency;
  final bool archived;

  factory Ledger.fromJson(Map<String, dynamic> json) => Ledger(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerId: json['owner_id'] as String?,
        currency: (json['currency'] as String?) ?? 'EUR',
        archived: (json['archived'] as bool?) ?? false,
      );
}
