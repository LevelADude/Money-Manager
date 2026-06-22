/// Zugriffs-Stufe einer Freigabe.
enum GrantLevel { view, manage }

GrantLevel grantLevelFromDb(String? s) =>
    s == 'manage' ? GrantLevel.manage : GrantLevel.view;

String grantLevelToDb(GrantLevel l) =>
    l == GrantLevel.manage ? 'manage' : 'view';

extension GrantLevelLabel on GrantLevel {
  String get label => switch (this) {
    GrantLevel.view => 'Ansehen',
    GrantLevel.manage => 'Verwalten',
  };
}

/// Eine Freigabe: [ownerId] erlaubt [granteeId] Zugriff (ansehen/verwalten) auf
/// die eigenen Konten + Buchungen.
class AccessGrant {
  const AccessGrant({
    required this.id,
    required this.ownerId,
    required this.granteeId,
    required this.level,
  });

  final String id;
  final String ownerId;
  final String granteeId;
  final GrantLevel level;

  factory AccessGrant.fromJson(Map<String, dynamic> j) => AccessGrant(
    id: j['id'] as String,
    ownerId: j['owner_id'] as String,
    granteeId: j['grantee_id'] as String,
    level: grantLevelFromDb(j['level'] as String?),
  );
}
