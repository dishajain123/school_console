import '../models/lifecycle/lifecycle_models.dart';
import 'enrollment_repository.dart';

/// Enrollment lifecycle helpers for the admin lifecycle screen (search, history, actions).
class LifecycleAdminRepository {
  LifecycleAdminRepository(this._api);

  final EnrollmentRepository _api;

  Future<List<LifecycleStudentSummary>> searchRoleProfiles({
    required String role,
    String? search,
    String? academicYearId,
    String? standardId,
    String? section,
  }) async {
    final items = await _api.searchRoleProfiles(
      role: role,
      search: search,
      academicYearId: academicYearId,
      standardId: standardId,
      section: section,
      pageSize: 100,
    );
    return items
        .map(
          (e) => LifecycleStudentSummary.fromRoleProfile(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<LifecycleStudentSummary>> listStudentsByClassFilters({
    required String standardId,
    required String academicYearId,
    String? sectionId,
  }) async {
    final data = await _api.getRoster(
      standardId: standardId,
      academicYearId: academicYearId,
      sectionId: sectionId,
    );
    final mappings = (data['mappings'] as List?) ?? [];
    return mappings.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return LifecycleStudentSummary(
        profileRole: 'STUDENT',
        studentId: m['student_id']?.toString() ?? '',
        userId: '',
        fullName: m['student_name'] as String?,
        email: null,
        admissionNumber: m['admission_number'] as String?,
        currentStandardName: m['standard_name'] as String?,
        currentSectionName:
            (m['section_name'] as String?) ?? (m['section'] as String?),
        currentStatus: m['status']?.toString(),
        currentMappingId: m['id']?.toString(),
        currentAcademicYearId: academicYearId,
        currentStandardId: standardId,
      );
    }).toList();
  }

  Future<List<LifecycleHistoryEntry>> getHistory(String studentId) async {
    final data = await _api.getStudentHistory(studentId);
    final history = (data['history'] as List?) ?? [];
    return history
        .map(
          (e) =>
              LifecycleHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> transferStudent({
    required String mappingId,
    required String newStandardId,
    String? newSectionId,
    String? newRollNumber,
    required String transferReason,
    String? effectiveDate,
  }) async {
    await _api.transferStudent(
      mappingId: mappingId,
      newStandardId: newStandardId,
      newSectionId: newSectionId,
      newRollNumber: newRollNumber,
      transferReason: transferReason,
      effectiveDate: effectiveDate,
    );
  }

  Future<void> exitStudent({
    required String mappingId,
    required String status,
    required String leftOn,
    required String exitReason,
  }) async {
    await _api.exitStudent(
      mappingId: mappingId,
      status: status,
      leftOn: leftOn,
      exitReason: exitReason,
    );
  }

  Future<void> completeMapping(String mappingId) async {
    await _api.completeMapping(mappingId);
  }

  Future<void> reenrollStudent({
    required String studentId,
    required String targetYearId,
    required String standardId,
    String? sectionId,
    String? rollNumber,
    String admissionType = 'READMISSION',
  }) async {
    await _api.reenrollStudent(
      studentId: studentId,
      targetYearId: targetYearId,
      standardId: standardId,
      sectionId: sectionId,
      rollNumber: rollNumber,
      admissionType: admissionType,
    );
  }

  Future<List<LifecycleAcademicYear>> getAcademicYears() async {
    final items = await _api.listAcademicYears();
    return items.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return LifecycleAcademicYear(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        isActive: m['is_active'] == true,
      );
    }).toList();
  }

  Future<List<LifecycleStandard>> getStandards() async {
    final items = await _api.listStandards();
    return items.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return LifecycleStandard(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        level: (m['level'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<LifecycleSection>> getSections({
    required String standardId,
    required String academicYearId,
  }) async {
    final items = await _api.listSections(
      standardId: standardId,
      academicYearId: academicYearId,
    );
    return items.map((e) {
      final m = Map<String, dynamic>.from(e);
      return LifecycleSection(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
      );
    }).toList();
  }
}
