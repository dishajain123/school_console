import '../../core/network/dio_client.dart';

class EnrollmentRepository {
  EnrollmentRepository(this._client);

  final DioClient _client;

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
}
