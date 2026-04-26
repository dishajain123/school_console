class AuditLog {
  AuditLog({
    required this.id,
    required this.userId,
    required this.actedById,
    required this.action,
    required this.fromStatus,
    required this.toStatus,
    required this.note,
    required this.actedAt,
  });

  final String id;
  final String userId;
  final String actedById;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? note;
  final DateTime actedAt;

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      actedById: json['acted_by_id'] as String,
      action: json['action'] as String,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String?,
      note: json['note'] as String?,
      actedAt: DateTime.parse(json['acted_at'] as String),
    );
  }
}
