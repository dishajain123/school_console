// lib/data/repositories/approval_repository.dart  [Admin Console]
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
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/approvals/queue',
      queryParameters: {'page': 1, 'page_size': 100},
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

  Future<List<RegistrationRequest>> queueByStatus(String status) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/approvals/queue',
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
      '/approvals/$userId',
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
      '/approvals/$userId/decision',
      data: {
        'action': action.apiValue,
        if (note != null && note.isNotEmpty) 'note': note,
        'override_validation': overrideValidation,
      },
    );
  }
}