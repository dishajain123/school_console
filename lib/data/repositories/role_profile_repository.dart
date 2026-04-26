import '../../core/network/dio_client.dart';
import '../models/role_profiles/identifier_config_item.dart';
import '../models/role_profiles/role_profile_item.dart';

class RoleProfileRepository {
  RoleProfileRepository(this._client);

  final DioClient _client;

  Future<RoleProfileListData> listProfiles({
    required String role,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/role-profiles',
      queryParameters: {
        'role': role,
        'page': page,
        'page_size': pageSize,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return RoleProfileListData.fromJson(resp.data ?? const {});
  }

  Future<List<IdentifierConfigItem>> getIdentifierConfigs() async {
    final resp = await _client.dio.get<List<dynamic>>('/role-profiles/identifier-configs');
    return (resp.data ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => IdentifierConfigItem.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
        .toList();
  }

  Future<IdentifierConfigItem> saveIdentifierConfig({
    required String identifierType,
    required String formatTemplate,
    required int sequencePadding,
    required bool resetYearly,
    String? prefix,
    String? schoolId,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/role-profiles/identifier-configs',
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
      },
      data: {
        'identifier_type': identifierType,
        'format_template': formatTemplate,
        'sequence_padding': sequencePadding,
        'reset_yearly': resetYearly,
        if (prefix != null && prefix.trim().isNotEmpty) 'prefix': prefix.trim(),
      },
    );
    return IdentifierConfigItem.fromJson(resp.data ?? const {});
  }
}
