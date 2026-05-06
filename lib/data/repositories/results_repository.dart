import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import 'masters_repository.dart';

class ResultsRepository {
  ResultsRepository(this._client) : _masters = MastersRepository(_client);

  final DioClient _client;
  final MastersRepository _masters;

  Future<List<Map<String, dynamic>>> listAcademicYears(String schoolId) =>
      _masters.listAcademicYears(schoolId: schoolId);

  Future<List<Map<String, dynamic>>> listStandards(
    String schoolId,
    String academicYearId,
  ) =>
      _masters.listStandards(
        schoolId: schoolId,
        academicYearId: academicYearId,
      );

  Future<List<String>> listResultSections({
    required String standardId,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.get<dynamic>(
      '${ApiConstants.results}/sections',
      queryParameters: {
        'standard_id': standardId,
        if (academicYearId != null && academicYearId.trim().isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    final raw = resp.data;
    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Pages until fewer than [pageSize] rows (caps at 50 pages server-side guard).
  Future<List<Map<String, dynamic>>> listStudentsMaps({
    required String standardId,
    String? academicYearId,
    String? section,
    int pageSize = 100,
    int maxPages = 50,
  }) async {
    final all = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final resp = await _client.dio.get<Map<String, dynamic>>(
        ApiConstants.students,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          'standard_id': standardId,
          if (academicYearId != null && academicYearId.trim().isNotEmpty)
            'academic_year_id': academicYearId.trim(),
          if (section != null && section.trim().isNotEmpty)
            'section': section.trim(),
        },
      );
      final batch = ((resp.data?['items'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      all.addAll(batch);
      if (batch.length < pageSize) break;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> listSubjectMaps({
    required String standardId,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.subjects,
      queryParameters: {'standard_id': standardId},
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Set<String>> listUploadedExamIds({
    String? academicYearId,
    String? standardId,
    String? section,
  }) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.resultsEntries,
      queryParameters: {
        if (academicYearId != null && academicYearId.trim().isNotEmpty)
          'academic_year_id': academicYearId,
        if (standardId != null && standardId.trim().isNotEmpty)
          'standard_id': standardId,
        if (section != null && section.trim().isNotEmpty)
          'section': section.trim(),
      },
    );
    final raw = (resp.data?['items'] as List?) ?? const [];
    final ids = <String>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final examId = map['exam_id']?.toString() ?? '';
      if (examId.trim().isNotEmpty) ids.add(examId);
    }
    return ids;
  }

  Future<List<Map<String, dynamic>>> listExamMaps({
    String? academicYearId,
    String? standardId,
  }) async {
    final resp = await _client.dio.get<dynamic>(
      ApiConstants.resultsExams,
      queryParameters: {
        if (academicYearId != null) 'academic_year_id': academicYearId,
        if (standardId != null) 'standard_id': standardId,
      },
    );
    final raw = resp.data is List
        ? resp.data as List
        : ((resp.data as Map?)?['items'] as List? ?? []);
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createExamForAllClasses({
    required String name,
    required String startDate,
    required String endDate,
    String? academicYearId,
  }) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.resultsExamsBulk,
      data: {
        'name': name,
        'apply_to_all_standards': true,
        if (academicYearId != null) 'academic_year_id': academicYearId,
        'start_date': startDate,
        'end_date': endDate,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getDistributionItems(
    String examId, {
    String? section,
  }) async {
    final resp = await _client.dio.get<dynamic>(
      ApiConstants.resultsExamDistribution(examId),
      queryParameters: {
        if (section != null && section.trim().isNotEmpty) 'section': section,
      },
    );
    final data = resp.data;
    if (data is! Map) {
      throw const FormatException('Unexpected distribution response shape');
    }
    final map = Map<String, dynamic>.from(data);
    final rawItems = map['items'];
    if (rawItems == null) return const [];
    if (rawItems is! List) {
      throw const FormatException('distribution.items is not a list');
    }
    return rawItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> deleteExam(String examId) async {
    await _client.dio.delete<dynamic>(ApiConstants.resultsExamDelete(examId));
  }

  Future<void> upsertResults({
    required String examId,
    required List<Map<String, dynamic>> entries,
  }) async {
    await _client.dio.post<dynamic>(
      '${ApiConstants.results}/entries',
      data: {
        'exam_id': examId,
        'entries': entries,
      },
    );
  }

  Future<void> uploadSchedule({
    required String standardId,
    required String examId,
    String? academicYearId,
    String? section,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    final normalizedSection = section?.trim();
    final sectionParam = (normalizedSection == null || normalizedSection.isEmpty)
        ? null
        : normalizedSection.toUpperCase();
    final formData = FormData.fromMap({
      'standard_id': standardId,
      'exam_id': examId,
      if (academicYearId != null && academicYearId.trim().isNotEmpty)
        'academic_year_id': academicYearId,
      if (sectionParam != null) 'section': sectionParam,
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    await _client.dio.post<dynamic>(
      ApiConstants.timetable,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> uploadReportCard({
    required String studentId,
    required String examId,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    final formData = FormData.fromMap({
      'student_id': studentId,
      'exam_id': examId,
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    await _client.dio.post<dynamic>(
      ApiConstants.resultsReportCardUpload,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  /// Returns `{'uploaded': false}` on 404, else keys `uploaded`, `uploaded_by_name`, `file_url`.
  Future<Map<String, dynamic>> getTimetableStatusMap({
    required String standardId,
    required String examId,
    String? academicYearId,
    String? section,
  }) async {
    try {
      final resp = await _client.dio.get<Map<String, dynamic>>(
        ApiConstants.timetableByStandard(standardId),
        queryParameters: {
          'exam_id': examId,
          if (academicYearId != null && academicYearId.trim().isNotEmpty)
            'academic_year_id': academicYearId,
          if (section != null && section.trim().isNotEmpty)
            'section': section.trim().toUpperCase(),
        },
      );
      final data = resp.data ?? const <String, dynamic>{};
      final uploadedBy = data['uploaded_by_name']?.toString();
      return {
        'uploaded': true,
        'uploaded_by_name': (uploadedBy != null && uploadedBy.trim().isNotEmpty)
            ? uploadedBy.trim()
            : null,
        'file_url': data['file_url']?.toString(),
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {'uploaded': false};
      }
      rethrow;
    }
  }

  Future<void> deleteTimetable({
    required String standardId,
    required String examId,
    String? academicYearId,
    String? section,
  }) async {
    await _client.dio.delete<void>(
      ApiConstants.timetableByStandard(standardId),
      queryParameters: {
        'exam_id': examId,
        if (academicYearId != null && academicYearId.trim().isNotEmpty)
          'academic_year_id': academicYearId.trim(),
        if (section != null && section.trim().isNotEmpty)
          'section': section.trim().toUpperCase(),
      },
    );
  }
}
