/// App-Profil (1:1 zu auth.users), siehe Tabelle `profiles`.
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.isAdmin,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final bool isAdmin;
  final DateTime? createdAt;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        displayName: (json['display_name'] as String?) ?? '',
        isAdmin: (json['is_admin'] as bool?) ?? false,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
      );
}
