import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/documents/admin_document_models.dart';
import 'masters_repository.dart';

class AdminDocumentRepository {
  AdminDocumentRepository(this._dio) : _masters = MastersRepository(_dio);

  final DioClient _dio;
  final MastersRepository _masters;

  Future<List<Map<String, dynamic>>> listYears() =>
      _masters.listAcademicYears();

  Future<List<Map<String, dynamic>>> listStandards(String yearId) =>
      _masters.listStandards(academicYearId: yearId);

  Future<List<String>> listSections({
    required String standardId,
    String? academicYearId,
  }) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.sections,
      queryParameters: {
        'standard_id': standardId,
        if (academicYearId != null && academicYearId.trim().isNotEmpty)
          'academic_year_id': academicYearId.trim(),
      },
    );
    final items = (r.data?['items'] as List?) ?? const <dynamic>[];
    return items
        .map((e) => (e as Map)['name']?.toString() ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<List<AdminDocument>> listAllDocuments({
    String? academicYearId,
    String? standardId,
    String? section,
    String? status,
  }) async {
    final query = <String, dynamic>{
      if (academicYearId != null && academicYearId.trim().isNotEmpty)
        'academic_year_id': academicYearId,
      if (standardId != null && standardId.trim().isNotEmpty)
        'standard_id': standardId,
      if (section != null && section.trim().isNotEmpty) 'section': section.trim(),
      if (status != null && status.trim().isNotEmpty)
        'status': status.trim().toUpperCase(),
    };
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.documents,
      queryParameters: query.isEmpty ? null : query,
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => AdminDocument.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AdminDocument>> listStudentDocuments(
    String studentId, {
    String? status,
  }) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.documents,
      queryParameters: {
        'student_id': studentId,
        if (status != null && status.trim().isNotEmpty)
          'status': status.trim().toUpperCase(),
      },
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => AdminDocument.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AdminRequirementStatus>> listRequirementStatus(
    String studentId,
  ) async {
    final r = await _dio.dio.get<dynamic>(
      ApiConstants.documentRequirementsStatus,
      queryParameters: {'student_id': studentId},
    );
    final data = r.data;
    if (data is! List) return [];
    return data
        .map((e) => AdminRequirementStatus.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<String?> getDownloadUrl(String docId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.documentDownload(docId),
    );
    return r.data?['url'] as String?;
  }

  Future<void> verifyDocument(
    String docId, {
    required bool approve,
    String? reason,
  }) async {
    await _dio.dio.patch<dynamic>(
      ApiConstants.documentVerify(docId),
      data: {
        'approve': approve,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<List<AdminDocRequirement>> getRequirements() async {
    final r = await _dio.dio
        .get<Map<String, dynamic>>(ApiConstants.documentRequirements);
    return ((r.data?['items'] as List?) ?? [])
        .map((e) =>
            AdminDocRequirement.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setRequirements(List<Map<String, dynamic>> items) async {
    await _dio.dio.put<dynamic>(
      ApiConstants.documentRequirements,
      data: {'items': items},
    );
  }

  Future<AdminDocument> uploadDocument({
    required String studentId,
    required String documentType,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
    String? note,
    String? academicYearId,
  }) async {
    final formData = FormData.fromMap({
      'student_id': studentId,
      'document_type': documentType,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (academicYearId != null && academicYearId.trim().isNotEmpty)
        'academic_year_id': academicYearId.trim(),
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final r = await _dio.dio.post<Map<String, dynamic>>(
      ApiConstants.documentUpload,
      data: formData,
    );
    return AdminDocument.fromJson(r.data ?? {});
  }

  Future<List<Map<String, dynamic>>> listStudents({
    String? academicYearId,
    int page = 1,
    int pageSize = 200,
  }) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.students,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (academicYearId != null && academicYearId.trim().isNotEmpty)
          'academic_year_id': academicYearId.trim(),
      },
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
