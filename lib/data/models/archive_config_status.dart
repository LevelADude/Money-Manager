/// Status der Archiv-Repo-Verbindung (ohne Geheimnisse). Kommt aus dem RPC
/// `get_archive_config_status`. Token/Schlüssel selbst verlassen den Server nie.
class ArchiveConfigStatus {
  const ArchiveConfigStatus({
    required this.configured,
    required this.repo,
    required this.hasToken,
    required this.hasKey,
  });

  /// Vollständig eingerichtet (Repo + Token + Schlüssel vorhanden)?
  final bool configured;
  final String? repo;
  final bool hasToken;
  final bool hasKey;

  static const empty = ArchiveConfigStatus(
    configured: false,
    repo: null,
    hasToken: false,
    hasKey: false,
  );

  factory ArchiveConfigStatus.fromJson(Map<String, dynamic> json) =>
      ArchiveConfigStatus(
        configured: (json['configured'] as bool?) ?? false,
        repo: json['github_repo'] as String?,
        hasToken: (json['has_token'] as bool?) ?? false,
        hasKey: (json['has_key'] as bool?) ?? false,
      );
}
