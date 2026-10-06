/// Model jejak audit (audit_logs).
class AuditLogModel {
  final int id;
  final int? userId;
  final String action;
  final String entityTable;
  final int? entityId;
  final String? description;
  final DateTime createdAt;

  /// Kolom tambahan hasil JOIN (tidak disimpan ke DB).
  final String? officerName;

  const AuditLogModel({
    required this.id,
    this.userId,
    required this.action,
    required this.entityTable,
    this.entityId,
    this.description,
    required this.createdAt,
    this.officerName,
  });

  factory AuditLogModel.fromMap(Map<String, Object?> map) {
    return AuditLogModel(
      id: map['id'] as int,
      userId: map['user_id'] as int?,
      action: map['action'] as String,
      entityTable: map['entity_table'] as String,
      entityId: map['entity_id'] as int?,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      officerName: map['full_name'] as String?,
    );
  }
}