// lib/data/repositories/approval_repository.dart  [Admin Console]
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/registration/approval_action.dart';
import '../models/registration/registration_request.dart';

class ApprovalRepository {
  ApprovalRepository(this._client);

  final DioClient _client;

  // FIXED: removed hardcoded status='PENDING_APPROVAL'.
  // Backend default now returns PENDING_APPROVAL + ON_HOLD + REJECTED together,
  // so all actionable users are visible in one queue view.
  Future<List<RegistrationRequest>> queue() async {
    return queueFiltered();
  }

  Future<List<RegistrationRequest>> queueFiltered({
    String? status,
    String? role,
    String? source,
    String? q,
    int page = 1,
    int pageSize = 100,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.approvalsQueue,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
        if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final items = ((resp.data?['items'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (e) => RegistrationRequest.fromQueueJson(
            e.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList();
    return items;
  }

  /// Total rows for the queue with the same filters as [queueFiltered] (uses API `total`).
  Future<int> queueTotal({
    String? status,
    String? role,
    String? source,
    String? q,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.approvalsQueue,
      queryParameters: {
        'page': 1,
        'page_size': 1,
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
        if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final raw = resp.data?['total'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<List<RegistrationRequest>> queueByStatus(String status) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.approvalsQueue,
      queryParameters: {'status': status, 'page': 1, 'page_size': 100},
    );
    final items = ((resp.data?['items'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (e) => RegistrationRequest.fromQueueJson(
            e.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList();
    return items;
  }

  Future<RegistrationRequest> detail(String userId) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.approvalUser(userId),
    );
    return RegistrationRequest.fromDetailJson(resp.data ?? {});
  }

  Future<void> decide({
    required String userId,
    required ApprovalActionType action,
    String? note,
    bool overrideValidation = false,
  }) async {
    await _client.dio.post(
      ApiConstants.approvalDecision(userId),
      data: {
        'action': action.apiValue,
        if (note != null && note.isNotEmpty) 'note': note,
        'override_validation': overrideValidation,
      },
    );
  }
}
