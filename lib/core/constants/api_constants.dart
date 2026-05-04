// lib/core/constants/api_constants.dart
// Admin Console API constants — complete with Phase 6/7 additions.
import 'package:flutter/foundation.dart';

class ApiConstants {
  // ── Base ──────────────────────────────────────────────────────────────────
  // Override with:
  // flutter run -d chrome --dart-define=ADMIN_API_BASE_URL=http://127.0.0.1:8000/api/v1
  // flutter run -d android --dart-define=ADMIN_API_BASE_URL=http://10.0.2.2:8000/api/v1
  static const String _baseUrlEnv = String.fromEnvironment(
    'ADMIN_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );
  static String get baseUrl {
    if (_baseUrlEnv.isNotEmpty) return _normalize(_baseUrlEnv);
    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? '127.0.0.1' : Uri.base.host;
      final safeHost = (host == '0.0.0.0' || host == '::') ? '127.0.0.1' : host;
      return 'http://$safeHost:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) return trimmed.substring(0, trimmed.length - 1);
    return trimmed;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String refresh = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';

  // ── Settings ──────────────────────────────────────────────────────────────
  static const String settings = '/settings';

  // ── Academic Years ────────────────────────────────────────────────────────
  static const String academicYears = '/academic-years';
  static String academicYearById(String id) => '/academic-years/$id';
  static String academicYearActivate(String id) =>
      '/academic-years/$id/activate';
  static String academicYearRollover(String id) =>
      '/academic-years/$id/rollover';

  // ── Masters ───────────────────────────────────────────────────────────────
  static const String standards = '/masters/standards';
  static String standardById(String id) => '/masters/standards/$id';
  static const String sections = '/masters/sections';
  static String sectionById(String id) => '/masters/sections/$id';
  static const String subjects = '/masters/subjects';
  static String subjectById(String id) => '/masters/subjects/$id';
  static const String grades = '/masters/grades';
  static String gradeById(String id) => '/masters/grades/$id';
  static const String gradesLookup = '/masters/grades/lookup';

  // ── Teacher Assignments ───────────────────────────────────────────────────
  static const String teacherAssignments = '/teacher-assignments';
  static const String teacherAssignmentsMine = '/teacher-assignments/mine';
  static String teacherAssignmentById(String id) => '/teacher-assignments/$id';

  // ── Users (school directory; user:manage / document:manage) ────────────────
  static const String users = '/users';

  // ── Teachers ──────────────────────────────────────────────────────────────
  static const String teachers = '/teachers';
  static String teacherById(String id) => '/teachers/$id';

  // ── Students ──────────────────────────────────────────────────────────────
  static const String students = '/students';
  static const String studentsMe = '/students/me';
  static const String studentSections = '/students/sections';
  static String studentById(String id) => '/students/$id';
  static String studentPromotionStatus(String id) =>
      '/students/$id/promotion-status';
  static const String studentBulkPromotionStatus =
      '/students/promotion-status/bulk';
  static const String studentSectionPromotionStatus =
      '/students/promotion-status/section';

  // ── Parents ───────────────────────────────────────────────────────────────
  static const String parents = '/parents';
  static String parentById(String id) => '/parents/$id';
  static String parentChildren(String id) => '/parents/$id/children';
  static const String myChildren = '/parents/me/children';
  static const String linkChild = '/parents/me/children/link';

  // ── Phase 6 & 7: Enrollment Mappings ─────────────────────────────────────
  static const String enrollmentMappings = '/enrollments/mappings';
  static String enrollmentMappingById(String id) =>
      '/enrollments/mappings/$id';
  static String enrollmentMappingTransfer(String mappingId) =>
      '/enrollments/mappings/$mappingId/transfer';
  static String enrollmentExit(String id) =>
      '/enrollments/mappings/$id/exit';
  static String enrollmentComplete(String id) =>
      '/enrollments/mappings/$id/complete';
  static const String enrollmentRoster = '/enrollments/roster';
  static const String enrollmentRollNumbers =
      '/enrollments/roll-numbers/assign';
  static String enrollmentHistory(String studentId) =>
      '/enrollments/history/$studentId';
  static const String enrollmentOnboardingQueue =
      '/enrollments/onboarding-queue';
  static String enrollmentAnnualReenroll(String userId) =>
      '/enrollments/annual-reenroll/$userId';

  // ── Phase 7: Promotion Workflow ───────────────────────────────────────────
  static const String promotionPreview = '/promotions/preview';
  static const String promotionExecute = '/promotions/execute';
  static String promotionReenroll(String studentId) =>
      '/promotions/reenroll/$studentId';
  static String promotionReenrollTeacher(String teacherId) =>
      '/promotions/reenroll-teacher/$teacherId';
  static const String promotionCopyAssignments =
      '/promotions/copy-teacher-assignments';

  // ── Fees ──────────────────────────────────────────────────────────────────
  static const String fees = '/fees';
  static const String feeStructures = '/fees/structures/batch';
  static const String feeStructuresList = '/fees/structures';
  static String feeStructureById(String id) => '/fees/structures/$id';
  static const String feeLedger = '/fees/ledger';
  static const String feeLedgerGenerate = '/fees/ledger/generate';
  static const String feeLedgerGenerateStudent =
      '/fees/ledger/generate-student';
  static const String feeLedgerClassStudents = '/fees/ledger/class-students';
  static const String feePayments = '/fees/payments';
  static const String feePaymentsAllocate = '/fees/payments/allocate';
  static const String feeAnalytics = '/fees/analytics';
  static const String feeDefaulters = '/fees/defaulters';

  // ── Assignments ───────────────────────────────────────────────────────────
  static const String assignments = '/assignments';
  static String assignmentById(String id) => '/assignments/$id';

  // ── Homework ──────────────────────────────────────────────────────────────
  static const String homework = '/homework';
  static String homeworkById(String id) => '/homework/$id';

  // ── Diary ─────────────────────────────────────────────────────────────────
  static const String diary = '/diary';

  // ── Timetable ─────────────────────────────────────────────────────────────
  static const String timetable = '/timetable';
  static String timetableSections(String standardId) =>
      '/timetable/$standardId/sections';

  // ── Exam Schedule ─────────────────────────────────────────────────────────
  static const String examSchedule = '/exam-schedule';

  // ── Results ───────────────────────────────────────────────────────────────
  static const String results = '/results';
  static const String resultsExams = '/results/exams';
  static const String resultsExamsBulk = '/results/exams/bulk';
  static String resultsExamDistribution(String examId) =>
      '/results/exams/$examId/distribution';
  static String resultsExamPublish(String examId) =>
      '/results/exams/$examId/publish';
  static String resultsExamDelete(String examId) => '/results/exams/$examId';

  // ── Documents ─────────────────────────────────────────────────────────────
  static const String documents = '/documents';
  static const String documentRequirements = '/documents/requirements';
  static const String documentUpload = '/documents/upload';
  static String documentDownload(String id) => '/documents/$id/download';
  static String documentVerify(String id) => '/documents/$id/verify';

  // ── Gallery ───────────────────────────────────────────────────────────────
  static const String gallery = '/gallery';

  // ── Leave ─────────────────────────────────────────────────────────────────
  static const String leave = '/leave';
  static String leaveById(String id) => '/leave/$id';
  static String leaveDecision(String id) => '/leave/$id/decision';
  static String leaveBalanceTeacher(String teacherId) =>
      '/leave/balance/teacher/$teacherId';

  // ── Chat ──────────────────────────────────────────────────────────────────
  static const String conversations = '/chat/conversations';
  static String conversationById(String id) => '/chat/conversations/$id';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notifications = '/notifications';

  // ── Announcements ─────────────────────────────────────────────────────────
  static const String announcements = '/announcements';
  static String announcementById(String id) => '/announcements/$id';

  // ── Complaints ────────────────────────────────────────────────────────────
  static const String complaints = '/complaints';

  // ── Behaviour ─────────────────────────────────────────────────────────────
  static const String behaviour = '/behaviour';

  // ── Principal Reports ─────────────────────────────────────────────────────
  static const String principalReports = '/principal-reports';
  static const String principalReportsOverview =
      '/principal-reports/overview';
  static const String principalReportsDetails =
      '/principal-reports/details';

  // ── Schools ───────────────────────────────────────────────────────────────
  static const String schools = '/schools';
  static String schoolById(String id) => '/schools/$id';

  // ── Role Profiles ─────────────────────────────────────────────────────────
  static const String roleProfiles = '/role-profiles';
  static const String identifierConfigs = '/role-profiles/identifier-configs';
  static const String roleProfilesTeacher = '/role-profiles/teacher';
  static const String roleProfilesStudent = '/role-profiles/student';
  static const String roleProfilesParent = '/role-profiles/parent';
  static String roleProfileByUserId(String userId) =>
      '/role-profiles/$userId';

  // ── Approvals (registration queue) ───────────────────────────────────────
  static const String approvalsQueue = '/approvals/queue';
  static String approvalUser(String userId) => '/approvals/$userId';
  static String approvalDecision(String userId) =>
      '/approvals/$userId/decision';

  // ── Audit logs ────────────────────────────────────────────────────────────
  static const String auditLogs = '/audit-logs';
  static const String auditLogActions = '/audit-logs/actions';
  static const String auditLogEntityTypes = '/audit-logs/entity-types';

  // ── Health (connectivity / smoke) ─────────────────────────────────────────
  static const String health = '/health';
}
