import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/role_profiles/identifier_config_item.dart';
import '../models/role_profiles/role_profile_item.dart';

class RoleProfileRepository {
  RoleProfileRepository(this._client);

  final DioClient _client;
  static const int _maxPageSize = 100;

  Future<RoleProfileListData> listProfiles({
    required String role,
    String? search,
    String? academicYearId,
    String? standardId,
    String? section,
    int page = 1,
    int pageSize = 20,
  }) async {
    final safePageSize = pageSize < 1
        ? 1
        : (pageSize > _maxPageSize ? _maxPageSize : pageSize);
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/role-profiles',
      queryParameters: {
        'role': role,
        'page': page,
        'page_size': safePageSize,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (academicYearId != null && academicYearId.isNotEmpty) 'academic_year_id': academicYearId,
        if (standardId != null && standardId.isNotEmpty) 'standard_id': standardId,
        if (section != null && section.trim().isNotEmpty) 'section': section.trim(),
      },
    );
    return RoleProfileListData.fromJson(resp.data ?? const {});
  }

  Future<List<Map<String, dynamic>>> listStandards({String? academicYearId}) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/masters/standards',
      queryParameters: {
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<String>> listSections({
    required String standardId,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/masters/sections',
      queryParameters: {
        'standard_id': standardId,
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items
        .map((e) => (e as Map)['name']?.toString() ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<List<Map<String, dynamic>>> listAcademicYears({String? schoolId}) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/academic-years',
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
      },
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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

  Future<List<String>> getParentChildIds(String parentId) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConstants.parentById(parentId)}/children',
    );
    final children = (resp.data?['children'] as List?) ?? const <dynamic>[];
    return children
        .whereType<Map>()
        .map((e) => (e['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<void> assignParentChildren({
    required String parentId,
    required List<String> studentIds,
  }) async {
    await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConstants.parentById(parentId)}/children',
      data: {
        'student_ids': studentIds,
      },
    );
  }

  Future<Map<String, dynamic>> createStudentProfile({
    required String userId,
    required String parentId,
    String? customAdmissionNumber,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/role-profiles/student',
      data: {
        'user_id': userId,
        'parent_id': parentId,
        if (customAdmissionNumber != null && customAdmissionNumber.trim().isNotEmpty)
          'custom_admission_number': customAdmissionNumber.trim(),
      },
    );
    return resp.data ?? <String, dynamic>{};
  }
}
