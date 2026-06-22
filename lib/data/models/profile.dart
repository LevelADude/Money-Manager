/// App-Profil (1:1 zu auth.users), siehe Tabelle `profiles`.
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.isAdmin,
    required this.createdAt,
    this.readOnly = false,
    this.isOwner = false,
  });

  final String id;
  final String displayName;
  final bool isAdmin;
  final DateTime? createdAt;
  final bool readOnly;

  /// Besitzer = erste registrierte Person. Immer Admin, geschützt (nicht
  /// degradierbar/löschbar). Genau einer pro Datenbank.
  final bool isOwner;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    displayName: (json['display_name'] as String?) ?? '',
    isAdmin: (json['is_admin'] as bool?) ?? false,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.tryParse(json['created_at'] as String),
    readOnly: (json['read_only'] as bool?) ?? false,
    isOwner: (json['is_owner'] as bool?) ?? false,
  );
}
