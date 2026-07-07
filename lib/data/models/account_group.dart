/// Eine eigene Konten-Gruppe für Custom-Summen, siehe Tabelle `account_groups`.
class AccountGroup {
  const AccountGroup({
    required this.id,
    required this.name,
    required this.accountIds,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final List<String> accountIds;
  final int sortOrder;

  factory AccountGroup.fromJson(Map<String, dynamic> json) => AccountGroup(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    accountIds:
        (json['account_ids'] as List?)?.map((e) => e as String).toList() ??
        const [],
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );
}
