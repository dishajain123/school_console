// lib/core/constants/route_constants.dart  [Admin Console]
class RouteNames {
  static const String login = '/login';

  // Phase 1 — Approvals & Audit
  static const String approvals = '/approvals';
  static const String approvalDetail = '/approvals/:userId';
  static const String audit = '/audit';

  // Phase 3 — Academic Structure
  static const String academics = '/academics';
  static const String academicStructure = '/academics/structure';

  // Phase 4 — Enrollment & Parent Linking
  static const String enrollment = '/enrollment';

  // Phase 2 — Role Profiles & Identifiers
  static const String roleProfiles = '/role-profiles';
  static const String identifierConfigs = '/role-profiles/identifier-configs';

  // Phase 5 — Admin Modules
  static const String users = '/users';
  static const String fees = '/fees';
  static const String reports = '/reports';
  static const String settings = '/settings';
}