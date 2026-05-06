import 'package:dio/dio.dart';

import '../../core/logging/crash_reporter.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import 'masters_repository.dart';

class TeacherAssignmentsRepository {
  TeacherAssignmentsRepository(this._client)
      : _masters = MastersRepository(_client);

  final DioClient _client;
  final MastersRepository _masters;

  Future<T> _withNetworkGuard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      final isNetwork =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.response == null;
      if (!isNetwork) rethrow;

      try {
        await _client.dio.get<Map<String, dynamic>>(ApiConstants.health);
      } catch (e2, stack2) {
        CrashReporter.log(e2, stack2);
        throw Exception(
          'Cannot reach backend server. Please ensure backend is running at ${_client.dio.options.baseUrl}.',
        );
      }
      throw Exception(
        'Network interrupted while loading teacher assignments. Please retry.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> listAssignmentsByTeacher(
    String teacherId,
    String? yearId,
  ) async {
    final resp = await _withNetworkGuard(
      () => _client.dio.get<Map<String, dynamic>>(
        ApiConstants.teacherAssignments,
        queryParameters: {
          'teacher_id': teacherId,
          if (yearId != null) 'academic_year_id': yearId,
        },
      ),
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listAssignmentsByClass(
    String standardId,
    String section,
    String? yearId,
  ) async {
    final resp = await _withNetworkGuard(
      () => _client.dio.get<Map<String, dynamic>>(
        ApiConstants.teacherAssignments,
        queryParameters: {
          'standard_id': standardId,
          'section': section,
          if (yearId != null) 'academic_year_id': yearId,
        },
      ),
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listAssignmentsByStandard(
    String standardId,
    String? yearId,
  ) async {
    final resp = await _withNetworkGuard(
      () => _client.dio.get<Map<String, dynamic>>(
        ApiConstants.teacherAssignments,
        queryParameters: {
          'standard_id': standardId,
          if (yearId != null) 'academic_year_id': yearId,
        },
      ),
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> createAssignment({
    required String teacherId,
    required String standardId,
    required String section,
    required String subjectId,
    required String academicYearId,
  }) async {
    await _client.dio.post<dynamic>(
      ApiConstants.teacherAssignments,
      data: {
        'teacher_id': teacherId,
        'standard_id': standardId,
        'section': section,
        'subject_id': subjectId,
        'academic_year_id': academicYearId,
      },
    );
  }

  Future<void> updateAssignment({
    required String assignmentId,
    required String standardId,
    required String section,
    required String subjectId,
    required String academicYearId,
  }) async {
    await _client.dio.patch<dynamic>(
      ApiConstants.teacherAssignmentById(assignmentId),
      data: {
        'standard_id': standardId,
        'section': section,
        'subject_id': subjectId,
        'academic_year_id': academicYearId,
      },
    );
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _client.dio.delete<dynamic>(
      ApiConstants.teacherAssignmentById(assignmentId),
    );
  }

  Future<Map<String, dynamic>> reenrollTeacher({
    required String teacherId,
    required String sourceYearId,
    required String targetYearId,
    bool overwriteExisting = false,
  }) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.promotionReenrollTeacher(teacherId),
      data: {
        'source_year_id': sourceYearId,
        'target_year_id': targetYearId,
        'overwrite_existing': overwriteExisting,
      },
    );
    return Map<String, dynamic>.from(r.data ?? const {});
  }

  Future<List<Map<String, dynamic>>> listAcademicYears() =>
      _masters.listAcademicYears();

  Future<Map<String, dynamic>> createAcademicYear({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.academicYears,
      data: {
        'name': name.trim(),
        'start_date': _fmtDate(startDate),
        'end_date': _fmtDate(endDate),
      },
    );
    return Map<String, dynamic>.from(r.data ?? {});
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<List<Map<String, dynamic>>> listTeacherRoleProfileMaps({
    int pageSize = 100,
  }) async {
    final r = await _withNetworkGuard(
      () => _client.dio.get<Map<String, dynamic>>(
        ApiConstants.roleProfiles,
        queryParameters: {'role': 'TEACHER', 'page_size': pageSize},
      ),
    );
    final items = (r.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, Map<String, dynamic>>> teacherEnrollmentStatusByUser({
    String? academicYearId,
  }) async {
    final r = await _withNetworkGuard(
      () => _client.dio.get<Map<String, dynamic>>(
        ApiConstants.enrollmentOnboardingQueue,
        queryParameters: {
          'role': 'TEACHER',
          'pending_only': false,
          if (academicYearId != null) 'academic_year_id': academicYearId,
        },
      ),
    );
    final items = (r.data?['items'] as List?) ?? [];
    final map = <String, Map<String, dynamic>>{};
    for (final item in items.whereType<Map>()) {
      final row = Map<String, dynamic>.from(item);
      final userId = (row['user_id'] ?? '').toString();
      if (userId.isNotEmpty) {
        map[userId] = row;
      }
    }
    return map;
  }

  Future<Map<String, dynamic>> createTeacherProfile({
    required String userId,
    String? customEmployeeId,
  }) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.roleProfilesTeacher,
      data: {
        'user_id': userId,
        if (customEmployeeId != null && customEmployeeId.trim().isNotEmpty)
          'custom_employee_id': customEmployeeId.trim(),
      },
    );
    return r.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listStandardMaps(String yearId) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.standards,
      queryParameters: {'academic_year_id': yearId},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listSectionMaps(
    String standardId,
    String yearId,
  ) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.sections,
      queryParameters: {'standard_id': standardId, 'academic_year_id': yearId},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listSubjectMaps({String? standardId}) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.subjects,
      queryParameters: {
        'page_size': 200,
        if (standardId != null) 'standard_id': standardId,
      },
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getTeacherLeaveBalances(
    String teacherId, {
    String? academicYearId,
  }) async {
    final resp = await _withNetworkGuard(
      () => _client.dio.get<List<dynamic>>(
        ApiConstants.leaveBalanceTeacher(teacherId),
        queryParameters: {
          if (academicYearId != null) 'academic_year_id': academicYearId,
        },
      ),
    );
    return (resp.data ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listTeacherLeaves(
    String teacherId, {
    String? academicYearId,
  }) async {
    final resp = await _withNetworkGuard(
      () => _client.dio.get<Map<String, dynamic>>(
        ApiConstants.leave,
        queryParameters: {
          'teacher_id': teacherId,
          if (academicYearId != null) 'academic_year_id': academicYearId,
        },
      ),
    );
    final items = (resp.data?['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> setTeacherLeaveBalances({
    required String teacherId,
    required String? academicYearId,
    required double casualDays,
    required double sickDays,
    required double earnedDays,
  }) async {
    final resp = await _withNetworkGuard(
      () => _client.dio.put<List<dynamic>>(
        ApiConstants.leaveBalanceTeacher(teacherId),
        data: {
          'allocations': [
            {'leave_type': 'CASUAL', 'total_days': casualDays},
            {'leave_type': 'SICK', 'total_days': sickDays},
            {'leave_type': 'EARNED', 'total_days': earnedDays},
          ],
          if (academicYearId != null) 'academic_year_id': academicYearId,
        },
      ),
    );
    return (resp.data ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
