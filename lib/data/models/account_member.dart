/// Mitgliedschaft an einem geteilten Konto (zusätzlich zum Besitzer).
class AccountMember {
  const AccountMember({
    required this.id,
    required this.accountId,
    required this.userId,
  });

  final String id;
  final String accountId;
  final String userId;

  factory AccountMember.fromJson(Map<String, dynamic> j) => AccountMember(
        id: j['id'] as String,
        accountId: j['account_id'] as String,
        userId: j['user_id'] as String,
      );
}
