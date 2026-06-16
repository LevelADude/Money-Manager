/// App-Profil (1:1 zu auth.users), siehe Tabelle `profiles`.
class Profile {
  const Profile({required this.id, required this.displayName});

  final String id;
  final String displayName;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        displayName: (json['display_name'] as String?) ?? '',
      );
}
