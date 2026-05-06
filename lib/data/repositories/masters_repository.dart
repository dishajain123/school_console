import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';

/// Shared GET helpers for academic-years / standards / sections list endpoints.
class MastersRepository {
  MastersRepository(this._client);

  final DioClient _client;

  Future<List<Map<String, dynamic>>> listAcademicYears({
    String? schoolId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.academicYears,
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
      },
    );
    return _items(resp.data);
  }

  Future<List<Map<String, dynamic>>> listStandards({
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
    return _items(resp.data);
  }

  Future<List<Map<String, dynamic>>> listSections({
    String? schoolId,
    String? standardId,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.sections,
      queryParameters: {
        if (schoolId != null && schoolId.isNotEmpty) 'school_id': schoolId,
        if (standardId != null && standardId.isNotEmpty)
          'standard_id': standardId,
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    return _items(resp.data);
  }

  static List<Map<String, dynamic>> _items(Map<String, dynamic>? data) {
    return ((data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
