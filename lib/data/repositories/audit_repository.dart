import '../../core/network/dio_client.dart';
import '../models/audit/audit_log.dart';

class AuditRepository {
  AuditRepository(this._client);

  final DioClient _client;

  Future<List<AuditLog>> list({int page = 1, int pageSize = 100}) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/approvals/audit/logs',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    final items = ((resp.data?['items'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (e) => AuditLog.fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
        )
        .toList();
    return items;
  }
}
