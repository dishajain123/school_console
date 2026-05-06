import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/academics/academic_year_item.dart';
import '../models/academics/section_item.dart';
import '../models/academics/standard_item.dart';
import '../models/academics/subject_item.dart';

class AcademicRepository {
  AcademicRepository(this._client);

  final DioClient _client;

  Future<String> resolveSchoolId(String? preferredSchoolId) async {
    if (preferredSchoolId != null && preferredSchoolId.isNotEmpty) {
      return preferredSchoolId;
    }
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.schools,
      queryParameters: {'page': 1, 'page_size': 1},
    );
    final items = (resp.data?['items'] as List?) ?? const <dynamic>[];
    if (items.isEmpty) {
      throw Exception('No schools found. Create a school first.');
    }
    final first = items.first;
    if (first is Map && first['id'] != null) {
      return first['id'].toString();
    }
    throw Exception('Unable to resolve school id');
  }

  Future<List<AcademicYearItem>> listYears({String? schoolId}) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.academicYears,
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? const <dynamic>[];
    return items
        .whereType<Map>()
        .map(
          (e) => AcademicYearItem.fromJson(
            e.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> listAcademicYearMaps({
    String? schoolId,
  }) async {
    final years = await listYears(schoolId: schoolId);
    return years
        .map(
          (y) => <String, dynamic>{
            'id': y.id,
            'name': y.name,
            'is_active': y.isActive,
            'start_date': _yyyyMmDd(y.startDate),
            'end_date': _yyyyMmDd(y.endDate),
            'school_id': y.schoolId,
          },
        )
        .toList();
  }

  Future<AcademicYearItem> createYear({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required String schoolId,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.academicYears,
      queryParameters: {'school_id': schoolId},
      data: {
        'name': name.trim(),
        'start_date': _yyyyMmDd(startDate),
        'end_date': _yyyyMmDd(endDate),
      },
    );
    return AcademicYearItem.fromJson(resp.data ?? const {});
  }

  Future<AcademicYearItem> activateYear({
    required String yearId,
    required String schoolId,
  }) async {
    final resp = await _client.dio.patch<Map<String, dynamic>>(
      ApiConstants.academicYearActivate(yearId),
      queryParameters: {'school_id': schoolId},
    );
    return AcademicYearItem.fromJson(resp.data ?? const {});
  }

  Future<List<StandardItem>> listStandards({
    required String schoolId,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.standards,
      queryParameters: {
        'school_id': schoolId,
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? const <dynamic>[];
    return items
        .whereType<Map>()
        .map(
          (e) =>
              StandardItem.fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
        )
        .toList();
  }

  Future<StandardItem> createStandard({
    required String schoolId,
    required String name,
    required int level,
    required String academicYearId,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.standards,
      queryParameters: {'school_id': schoolId},
      data: {
        'name': name.trim(),
        'level': level,
        'academic_year_id': academicYearId,
      },
    );
    return StandardItem.fromJson(resp.data ?? const {});
  }

  Future<List<SectionItem>> listSections({
    required String schoolId,
    String? academicYearId,
    String? standardId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.sections,
      queryParameters: {
        'school_id': schoolId,
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
        if (standardId != null && standardId.isNotEmpty)
          'standard_id': standardId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? const <dynamic>[];
    return items
        .whereType<Map>()
        .map(
          (e) =>
              SectionItem.fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
        )
        .toList();
  }

  Future<SectionItem> createSection({
    required String schoolId,
    required String standardId,
    required String academicYearId,
    required String sectionName,
    int? capacity,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.sections,
      queryParameters: {'school_id': schoolId},
      data: {
        'standard_id': standardId,
        'academic_year_id': academicYearId,
        'name': sectionName.trim().toUpperCase(),
        'capacity': capacity,
      },
    );
    return SectionItem.fromJson(resp.data ?? const {});
  }

  Future<List<SubjectItem>> listSubjects({
    required String schoolId,
    String? standardId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.subjects,
      queryParameters: {
        'school_id': schoolId,
        if (standardId != null && standardId.isNotEmpty)
          'standard_id': standardId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? const <dynamic>[];
    return items
        .whereType<Map>()
        .map(
          (e) =>
              SubjectItem.fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
        )
        .toList();
  }

  Future<SubjectItem> createSubject({
    required String schoolId,
    required String name,
    required String code,
    String? standardId,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.subjects,
      queryParameters: {'school_id': schoolId},
      data: {
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        if (standardId != null && standardId.isNotEmpty)
          'standard_id': standardId,
      },
    );
    return SubjectItem.fromJson(resp.data ?? const {});
  }

  Future<void> patchStandard({
    required String standardId,
    required String name,
    required int level,
    required String academicYearId,
  }) async {
    await _client.dio.patch<dynamic>(
      ApiConstants.standardById(standardId),
      data: {
        'name': name.trim(),
        'level': level,
        'academic_year_id': academicYearId,
      },
    );
  }

  Future<void> deleteStandard(String standardId) async {
    await _client.dio.delete<dynamic>(ApiConstants.standardById(standardId));
  }

  Future<void> patchSection({
    required String sectionId,
    required String sectionName,
    int? capacity,
  }) async {
    await _client.dio.patch<dynamic>(
      ApiConstants.sectionById(sectionId),
      data: {
        'name': sectionName.trim().toUpperCase(),
        if (capacity != null) 'capacity': capacity,
      },
    );
  }

  Future<void> deleteSection(String sectionId) async {
    await _client.dio.delete<dynamic>(ApiConstants.sectionById(sectionId));
  }

  Future<void> createSubjectScoped({
    required String standardId,
    required String name,
    required String code,
  }) async {
    await _client.dio.post<dynamic>(
      ApiConstants.subjects,
      data: {
        'standard_id': standardId,
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
      },
    );
  }

  Future<void> patchSubject({
    required String subjectId,
    required String standardId,
    required String name,
    required String code,
  }) async {
    await _client.dio.patch<dynamic>(
      ApiConstants.subjectById(subjectId),
      data: {
        'standard_id': standardId,
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
      },
    );
  }

  Future<void> deleteSubject(String subjectId) async {
    await _client.dio.delete<dynamic>(ApiConstants.subjectById(subjectId));
  }

  Future<List<Map<String, dynamic>>> listStandardsMaps({
    String? schoolId,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.standards,
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listSectionsMaps({
    String? schoolId,
    required String standardId,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.sections,
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
        'standard_id': standardId,
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listSubjectsMaps({
    String? schoolId,
    String? standardId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.subjects,
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
        if (standardId != null && standardId.isNotEmpty)
          'standard_id': standardId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createAcademicYearReturningMap({
    required String schoolId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.academicYears,
      queryParameters: {'school_id': schoolId},
      data: {
        'name': name.trim(),
        'start_date': _yyyyMmDd(startDate),
        'end_date': _yyyyMmDd(endDate),
      },
    );
    return Map<String, dynamic>.from(resp.data ?? const {});
  }

  Future<List<Map<String, dynamic>>> listTeacherAssignmentsForStandardMaps({
    String? schoolId,
    required String standardId,
    required String academicYearId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.teacherAssignments,
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
        'standard_id': standardId,
        'academic_year_id': academicYearId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  String _yyyyMmDd(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
