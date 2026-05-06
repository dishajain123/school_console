// Models for admin student lifecycle (search, history, filters).
// Used by [LifecycleAdminRepository] and the lifecycle management screen.

class LifecycleStudentSummary {
  const LifecycleStudentSummary({
    required this.profileRole,
    required this.studentId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.admissionNumber,
    required this.currentStandardName,
    required this.currentSectionName,
    required this.currentStatus,
    required this.currentMappingId,
    required this.currentAcademicYearId,
    required this.currentStandardId,
  });

  final String profileRole;
  final String studentId;
  final String userId;
  final String? fullName;
  final String? email;
  final String? admissionNumber;
  final String? currentStandardName;
  final String? currentSectionName;
  final String? currentStatus;
  final String? currentMappingId;
  final String? currentAcademicYearId;
  final String? currentStandardId;

  bool get isEnrollmentLifecycleTarget =>
      profileRole == 'STUDENT' && studentId.trim().isNotEmpty;

  factory LifecycleStudentSummary.fromJson(Map<String, dynamic> j) {
    final role = (j['role'] as String?)?.toUpperCase() ?? 'STUDENT';
    return LifecycleStudentSummary(
      profileRole: role,
      studentId: j['student_id']?.toString() ?? j['id']?.toString() ?? '',
      userId: j['user_id']?.toString() ?? '',
      fullName: j['full_name'] as String?,
      email: j['email'] as String?,
      admissionNumber: j['admission_number'] as String?,
      currentStandardName: j['standard_name'] as String?,
      currentSectionName: j['section'] as String?,
      currentStatus: j['enrollment_status'] as String?,
      currentMappingId: j['mapping_id'] as String?,
      currentAcademicYearId: j['academic_year_id'] as String?,
      currentStandardId: j['standard_id']?.toString(),
    );
  }

  factory LifecycleStudentSummary.fromRoleProfile(Map<String, dynamic> j) {
    final role = (j['role'] as String?)?.toUpperCase() ?? 'STUDENT';
    switch (role) {
      case 'TEACHER':
        return LifecycleStudentSummary(
          profileRole: 'TEACHER',
          studentId: '',
          userId: j['user_id']?.toString() ?? '',
          fullName: j['full_name'] as String?,
          email: j['email'] as String?,
          admissionNumber:
              j['employee_id']?.toString() ?? j['identifier']?.toString(),
          currentStandardName: j['specialization'] as String?,
          currentSectionName: null,
          currentStatus: null,
          currentMappingId: null,
          currentAcademicYearId: null,
          currentStandardId: null,
        );
      case 'PARENT':
        return LifecycleStudentSummary(
          profileRole: 'PARENT',
          studentId: '',
          userId: j['user_id']?.toString() ?? '',
          fullName: j['full_name'] as String?,
          email: j['email'] as String?,
          admissionNumber:
              j['parent_code']?.toString() ?? j['identifier']?.toString(),
          currentStandardName: j['occupation'] as String?,
          currentSectionName: j['relation']?.toString(),
          currentStatus: null,
          currentMappingId: null,
          currentAcademicYearId: null,
          currentStandardId: null,
        );
      case 'PRINCIPAL':
      case 'TRUSTEE':
        return LifecycleStudentSummary(
          profileRole: role,
          studentId: '',
          userId: j['user_id']?.toString() ?? '',
          fullName: j['full_name'] as String?,
          email: j['email'] as String?,
          admissionNumber: j['identifier']?.toString(),
          currentStandardName: null,
          currentSectionName: null,
          currentStatus: j['status']?.toString(),
          currentMappingId: null,
          currentAcademicYearId: null,
          currentStandardId: null,
        );
      default:
        return LifecycleStudentSummary(
          profileRole: 'STUDENT',
          studentId: j['student_id']?.toString() ?? '',
          userId: j['user_id']?.toString() ?? '',
          fullName: j['full_name'] as String?,
          email: j['email'] as String?,
          admissionNumber: j['admission_number'] as String?,
          currentStandardName: null,
          currentSectionName: j['section'] as String?,
          currentStatus: j['enrollment_completed'] == true ? 'ACTIVE' : null,
          currentMappingId: null,
          currentAcademicYearId: null,
          currentStandardId: j['standard_id']?.toString(),
        );
    }
  }

  LifecycleStudentSummary copyWith({
    String? currentStandardName,
    String? currentSectionName,
    String? currentStatus,
    String? currentMappingId,
    String? currentAcademicYearId,
    String? currentStandardId,
  }) {
    return LifecycleStudentSummary(
      profileRole: profileRole,
      studentId: studentId,
      userId: userId,
      fullName: fullName,
      email: email,
      admissionNumber: admissionNumber,
      currentStandardName: currentStandardName ?? this.currentStandardName,
      currentSectionName: currentSectionName ?? this.currentSectionName,
      currentStatus: currentStatus ?? this.currentStatus,
      currentMappingId: currentMappingId ?? this.currentMappingId,
      currentAcademicYearId: currentAcademicYearId ?? this.currentAcademicYearId,
      currentStandardId: currentStandardId ?? this.currentStandardId,
    );
  }
}

class LifecycleHistoryEntry {
  const LifecycleHistoryEntry({
    required this.id,
    required this.academicYearName,
    required this.standardName,
    required this.sectionName,
    required this.rollNumber,
    required this.status,
    required this.admissionType,
    required this.joinedOn,
    this.leftOn,
    this.exitReason,
  });

  final String id;
  final String? academicYearName;
  final String? standardName;
  final String? sectionName;
  final String? rollNumber;
  final String status;
  final String? admissionType;
  final String? joinedOn;
  final String? leftOn;
  final String? exitReason;

  factory LifecycleHistoryEntry.fromJson(Map<String, dynamic> j) =>
      LifecycleHistoryEntry(
        id: j['id']?.toString() ?? '',
        academicYearName: j['academic_year_name'] as String?,
        standardName: j['standard_name'] as String?,
        sectionName: j['section_name'] as String?,
        rollNumber: j['roll_number'] as String?,
        status: j['status']?.toString() ?? 'UNKNOWN',
        admissionType: j['admission_type'] as String?,
        joinedOn: j['joined_on'] as String?,
        leftOn: j['left_on'] as String?,
        exitReason: j['exit_reason'] as String?,
      );
}

class LifecycleAcademicYear {
  const LifecycleAcademicYear({
    required this.id,
    required this.name,
    required this.isActive,
  });
  final String id;
  final String name;
  final bool isActive;
}

class LifecycleStandard {
  const LifecycleStandard({
    required this.id,
    required this.name,
    required this.level,
  });
  final String id;
  final String name;
  final int level;
}

class LifecycleSection {
  const LifecycleSection({required this.id, required this.name});
  final String id;
  final String name;
}
