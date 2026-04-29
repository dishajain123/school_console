import '../../core/network/dio_client.dart';

class EnrollmentRepository {
  EnrollmentRepository(this._client);

  final DioClient _client;
  static const int _roleProfilesMaxPageSize = 100;

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

  Future<List<Map<String, dynamic>>> listStandards({
    String? schoolId,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/masters/standards',
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listSections({
    String? schoolId,
    String? standardId,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/masters/sections',
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
        if (standardId != null && standardId.isNotEmpty) 'standard_id': standardId,
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getRoster({
    required String standardId,
    required String academicYearId,
    String? sectionId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/enrollments/roster',
      queryParameters: {
        'standard_id': standardId,
        'academic_year_id': academicYearId,
        if (sectionId != null && sectionId.isNotEmpty) 'section_id': sectionId,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<void> createMapping({
    required String studentId,
    required String standardId,
    required String academicYearId,
    String? sectionId,
    String? rollNumber,
  }) async {
    await _client.dio.post<dynamic>(
      '/enrollments/mappings',
      data: {
        'student_id': studentId,
        'standard_id': standardId,
        'academic_year_id': academicYearId,
        if (sectionId != null && sectionId.isNotEmpty) 'section_id': sectionId,
        if (rollNumber != null && rollNumber.isNotEmpty) 'roll_number': rollNumber,
      },
    );
  }

  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/role-profiles',
      queryParameters: {
        'role': 'STUDENT',
        'search': query,
        'page': 1,
        'page_size': 20,
      },
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getStudentHistory(String studentId) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/enrollments/history/$studentId',
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<void> transferStudent({
    required String mappingId,
    required String newStandardId,
    String? newSectionId,
    String? newRollNumber,
    required String transferReason,
    String? effectiveDate,
  }) async {
    await _client.dio.post<dynamic>(
      '/enrollments/mappings/$mappingId/transfer',
      data: {
        'new_standard_id': newStandardId,
        if (newSectionId != null && newSectionId.isNotEmpty)
          'new_section_id': newSectionId,
        if (newRollNumber != null && newRollNumber.isNotEmpty)
          'new_roll_number': newRollNumber,
        'transfer_reason': transferReason,
        if (effectiveDate != null && effectiveDate.isNotEmpty)
          'effective_date': effectiveDate,
      },
    );
  }

  Future<void> exitStudent({
    required String mappingId,
    required String status,
    required String leftOn,
    required String exitReason,
  }) async {
    await _client.dio.post<dynamic>(
      '/enrollments/mappings/$mappingId/exit',
      data: {
        'status': status,
        'left_on': leftOn,
        'exit_reason': exitReason,
      },
    );
  }

  Future<void> completeMapping(String mappingId, {String? completedOn}) async {
    await _client.dio.post<dynamic>(
      '/enrollments/mappings/$mappingId/complete',
      data: {
        if (completedOn != null && completedOn.isNotEmpty)
          'completed_on': completedOn,
      },
    );
  }

  Future<Map<String, dynamic>> previewPromotion({
    required String sourceYearId,
    required String targetYearId,
    String? standardId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/promotions/preview',
      queryParameters: {
        'source_year_id': sourceYearId,
        'target_year_id': targetYearId,
        if (standardId != null && standardId.isNotEmpty) 'standard_id': standardId,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> executePromotion({
    required String sourceYearId,
    required String targetYearId,
    required List<Map<String, dynamic>> items,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/promotions/execute',
      data: {
        'source_year_id': sourceYearId,
        'target_year_id': targetYearId,
        'items': items,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> copyTeacherAssignments({
    required String sourceYearId,
    required String targetYearId,
    bool overwriteExisting = false,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/promotions/copy-teacher-assignments',
      data: {
        'source_year_id': sourceYearId,
        'target_year_id': targetYearId,
        'overwrite_existing': overwriteExisting,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> reenrollStudent({
    required String studentId,
    required String targetYearId,
    required String standardId,
    String? sectionId,
    String? rollNumber,
    String admissionType = 'READMISSION',
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/promotions/reenroll/$studentId',
      data: {
        'target_year_id': targetYearId,
        'standard_id': standardId,
        if (sectionId != null && sectionId.isNotEmpty) 'section_id': sectionId,
        if (rollNumber != null && rollNumber.isNotEmpty) 'roll_number': rollNumber,
        'admission_type': admissionType,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getRoleProfile(String userId) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/role-profiles/$userId',
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listParentProfiles({
    String? search,
    int pageSize = 200,
  }) async {
    final items = <Map<String, dynamic>>[];
    final target = pageSize < 1 ? 1 : pageSize;
    var page = 1;
    while (items.length < target) {
      final perPage = (target - items.length) > _roleProfilesMaxPageSize
          ? _roleProfilesMaxPageSize
          : (target - items.length);
      final resp = await _client.dio.get<Map<String, dynamic>>(
        '/role-profiles',
        queryParameters: {
          'role': 'PARENT',
          'page': page,
          'page_size': perPage,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final batch = ((resp.data?['items'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (batch.isEmpty) break;
      items.addAll(batch);
      if (batch.length < perPage) break;
      page += 1;
    }
    return items.take(target).toList();
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

  Future<Map<String, dynamic>> createParentProfile({
    required String userId,
    String relation = 'GUARDIAN',
    String? occupation,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/role-profiles/parent',
      data: {
        'user_id': userId,
        'relation': relation,
        if (occupation != null && occupation.trim().isNotEmpty)
          'occupation': occupation.trim(),
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listStudentProfiles({
    String? search,
    int pageSize = 300,
  }) async {
    final items = <Map<String, dynamic>>[];
    final target = pageSize < 1 ? 1 : pageSize;
    var page = 1;
    while (items.length < target) {
      final perPage = (target - items.length) > _roleProfilesMaxPageSize
          ? _roleProfilesMaxPageSize
          : (target - items.length);
      final resp = await _client.dio.get<Map<String, dynamic>>(
        '/role-profiles',
        queryParameters: {
          'role': 'STUDENT',
          'page': page,
          'page_size': perPage,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final batch = ((resp.data?['items'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (batch.isEmpty) break;
      items.addAll(batch);
      if (batch.length < perPage) break;
      page += 1;
    }
    return items.take(target).toList();
  }

  Future<List<String>> getParentChildIds(String parentId) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/parents/$parentId/children',
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
      '/parents/$parentId/children',
      data: {
        'student_ids': studentIds,
      },
    );
  }

  Future<List<Map<String, dynamic>>> onboardingQueue({
    String? role,
    bool pendingOnly = true,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/enrollments/onboarding-queue',
      queryParameters: {
        if (role != null && role.isNotEmpty) 'role': role,
        'pending_only': pendingOnly,
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    return ((resp.data?['items'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }
}
