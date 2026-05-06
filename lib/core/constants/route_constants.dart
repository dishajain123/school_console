// lib/core/constants/route_constants.dart  [Admin Console]
class RouteNames {
  static const String login = '/login';

  /// Shown when a signed-in user opens a route they are not permitted to use.
  static const String accessDenied = '/access-denied';

  /// Signed-in landing (sidebar home).
  static const String dashboard = '/dashboard';

  // Phase 1 — Approvals & Audit
  static const String approvals = '/approvals';
  static const String approvalDetail = '/approvals/:userId';

  // Phase 14 — Audit & Traceability (full system-wide trail)
  static const String audit = '/audit';

  // Phase 3 — Academic Structure
  static const String academics = '/academics';
  static const String academicStructure = '/academics/structure';

  // Phase 4 & 6 — Enrollment
  static const String enrollment = '/enrollment';

  // Phase 7 — Promotion Workflow
  static const String promotion = '/enrollment/promotion';

  // Phase 14/15 — Student Lifecycle Management (unified screen)
  static const String lifecycleManagement = '/enrollment/lifecycle';

  // Phase 4 — Teacher Assignment Management (assign teacher → subject → class → section)
  static const String teacherAssignments = '/teacher-assignments';

  // Phase 2 — Role Profiles & Identifiers
  static const String roleProfiles = '/role-profiles';

  // Phase 8 — Fees Management
  static const String fees = '/fees';

  // Phase 10 — Examination
  static const String examination = '/examination';

  // Phase 11 — Reporting & Analytics
  static const String reports = '/reports';

  // Phase 12 — Notifications & Communication
  static const String communication = '/communication';

  // Phase 13 — Document Management
  static const String documents = '/documents';
  static const String documentStudentDetail = '/documents/student';

  static const String settings = '/settings';
}
