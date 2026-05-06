import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import 'masters_repository.dart';

class PrincipalReportsRepository {
  PrincipalReportsRepository(this._client)
    : _masters = MastersRepository(_client);

  final DioClient _client;
  final MastersRepository _masters;

  Future<List<Map<String, dynamic>>> listAcademicYears(String schoolId) =>
      _masters.listAcademicYears(schoolId: schoolId);

  Future<List<Map<String, dynamic>>> listStandards(
    String schoolId,
    String yearId,
  ) => _masters.listStandards(schoolId: schoolId, academicYearId: yearId);

  Future<Map<String, dynamic>> getOverview({String? yearId}) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.principalReportsOverview,
      queryParameters: {if (yearId != null) 'academic_year_id': yearId},
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> getDetails({
    String? yearId,
    String? metric,
    String? standardId,
    String? section,
  }) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.principalReportsDetails,
      queryParameters: {
        if (yearId != null) 'academic_year_id': yearId,
        if (metric != null) 'metric': metric,
        if (standardId != null) 'standard_id': standardId,
        if (section != null && section.trim().isNotEmpty) 'section': section,
      },
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> getFeeAnalytics({
    String? yearId,
    String? standardId,
  }) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.feeAnalytics,
      queryParameters: {
        if (yearId != null) 'academic_year_id': yearId,
        if (standardId != null) 'standard_id': standardId,
      },
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> getStudentStrengthPage(
    String schoolId,
    String yearId,
  ) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.students,
      queryParameters: {'academic_year_id': yearId, 'page': 1, 'page_size': 1},
    );
    return r.data ?? {};
  }

  Future<List<Map<String, dynamic>>> getDefaulters({String? yearId}) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.feeDefaulters,
      queryParameters: {if (yearId != null) 'academic_year_id': yearId},
    );
    return ((r.data?['defaulters'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
