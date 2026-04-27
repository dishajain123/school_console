// lib/data/models/audit/audit_log.dart  [Admin Console]
// Phase 14 — Audit & Traceability.
// Model aligned with GET /audit-logs backend response (AuditLogResponse schema).
// Old approval-audit fields (userId, actedById, fromStatus, toStatus) are removed.
// New fields: actorId, actorName, targetUserId, entityType, entityId,
//             description, beforeState, afterState, ipAddress, occurredAt.

class AuditLog {
  AuditLog({
    required this.id,
    required this.action,
    required this.entityType,
    required this.description,
    required this.occurredAt,
    this.schoolId,
    this.actorId,
    this.actorName,
    this.targetUserId,
    this.entityId,
    this.beforeState,
    this.afterState,
    this.ipAddress,
  });

  final String id;
  final String? schoolId;
  final String? actorId;
  final String? actorName;
  final String? targetUserId;
  final String action;
  final String entityType;
  final String? entityId;
  final String description;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;
  final String? ipAddress;
  final DateTime occurredAt;

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id'] as String?,
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String?,
      targetUserId: json['target_user_id'] as String?,
      action: json['action']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id'] as String?,
      description: json['description']?.toString() ?? '',
      beforeState: json['before_state'] != null
          ? Map<String, dynamic>.from(json['before_state'] as Map)
          : null,
      afterState: json['after_state'] != null
          ? Map<String, dynamic>.from(json['after_state'] as Map)
          : null,
      ipAddress: json['ip_address'] as String?,
      occurredAt: json['occurred_at'] != null
          ? DateTime.tryParse(json['occurred_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}