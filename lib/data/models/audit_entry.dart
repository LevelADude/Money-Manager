/// Ein Eintrag im Änderungsverlauf (audit_log).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.rowId,
    required this.action,
    required this.actor,
    required this.at,
    required this.data,
  });

  final int id;
  final String? rowId;
  final String action; // insert | update | delete | restore | purge
  final String? actor; // profile-id
  final DateTime at;
  final Map<String, dynamic>? data;

  String get actionLabel => switch (action) {
        'insert' => 'Angelegt',
        'update' => 'Geändert',
        'delete' => 'Gelöscht',
        'restore' => 'Wiederhergestellt',
        'purge' => 'Endgültig gelöscht',
        _ => action,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: (json['id'] as num).toInt(),
        rowId: json['row_id'] as String?,
        action: (json['action'] as String?) ?? 'update',
        actor: json['actor'] as String?,
        at: DateTime.parse(json['at'] as String),
        data: json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : null,
      );
}
