// lib/data/repositories/audit_repository.dart  [Admin Console]
// Phase 14 — Audit & Traceability.
// FIXED: endpoint changed from /approvals/audit/logs → /audit-logs.
// FIXED: filter params added to match backend (action, entity_type, actor_id,
//        target_user_id, date_from, date_to, q).
// FIXED: model fields updated to match AuditLogResponse (occurredAt, entityType, etc.).

import '../../core/network/dio_client.dart';
import '../models/audit/audit_log.dart';

class AuditRepository {
  AuditRepository(this._client);

  final DioClient _client;

  Future<List<AuditLog>> list({
    int page = 1,
    int pageSize = 50,
    String? action,
    String? entityType,
    String? actorId,
    String? targetUserId,
    String? dateFrom,
    String? dateTo,
    String? q,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (action != null && action.isNotEmpty) params['action'] = action;
    if (entityType != null && entityType.isNotEmpty) {
      params['entity_type'] = entityType;
    }
    if (actorId != null && actorId.isNotEmpty) params['actor_id'] = actorId;
    if (targetUserId != null && targetUserId.isNotEmpty) {
      params['target_user_id'] = targetUserId;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (q != null && q.isNotEmpty) params['q'] = q;

    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/audit-logs',
      queryParameters: params,
    );

    final items = ((resp.data?['items'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (e) => AuditLog.fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
        )
        .toList();
    return items;
  }

  Future<List<String>> listActions() async {
    final resp = await _client.dio.get<List<dynamic>>('/audit-logs/actions');
    return ((resp.data ?? const <dynamic>[]) as List)
        .map((e) => e.toString())
        .toList();
  }

  Future<List<String>> listEntityTypes() async {
    final resp =
        await _client.dio.get<List<dynamic>>('/audit-logs/entity-types');
    return ((resp.data ?? const <dynamic>[]) as List)
        .map((e) => e.toString())
        .toList();
  }
}