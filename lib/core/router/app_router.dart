// lib/core/router/app_router.dart  [Admin Console]
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_constants.dart';
import '../../domains/providers/auth_provider.dart';
import '../../presentation/approvals/screens/approval_detail_screen.dart';
import '../../presentation/approvals/screens/approval_queue_screen.dart';
import '../../presentation/audit/screens/audit_log_screen.dart';
import '../../presentation/auth/screens/admin_login_screen.dart';
import '../../presentation/academics/screens/academic_years_screen.dart';
import '../../presentation/academics/screens/academic_structure_screen.dart';
import '../../presentation/enrollment/screens/enrollment_screen.dart';
import '../../presentation/enrollment/screens/promotion_workflow_screen.dart';
import '../../presentation/teacher_assignments/screens/teacher_assignment_screen.dart';
import '../../presentation/role_profiles/screens/identifier_config_screen.dart';
import '../../presentation/role_profiles/screens/role_profiles_screen.dart';
import '../../presentation/users/screens/users_management_screen.dart';
import '../../presentation/fees/screens/fee_management_screen.dart';
import '../../presentation/attendance/screens/attendance_monitor_screen.dart';
import '../../domains/providers/results/screens/exams_results_screen.dart';
import '../../presentation/reports/screens/reports_screen.dart';
import '../../presentation/communication/screens/communication_screen.dart';
import '../../presentation/documents/screens/document_management_screen.dart';
import '../../presentation/bulk/screens/bulk_operations_screen.dart';
import '../../presentation/settings/screens/settings_screen.dart';

GoRouter buildRouter() {
  final container = ProviderContainer();

  return GoRouter(
    initialLocation: RouteNames.login,
    redirect: (context, state) {
      final authState = container.read(authControllerProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginPage = state.matchedLocation == RouteNames.login;

      if (!isLoggedIn && !isLoginPage) return RouteNames.login;
      if (isLoggedIn && isLoginPage) return RouteNames.approvals;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const AdminLoginScreen(),
      ),

      // Phase 1 — Approvals
      GoRoute(
        path: RouteNames.approvals,
        builder: (context, state) => const ApprovalQueueScreen(),
      ),
      GoRoute(
        path: '/approvals/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return ApprovalDetailScreen(userId: userId);
        },
      ),

      // Phase 14 — Audit Log (full system-wide)
      GoRoute(
        path: RouteNames.audit,
        builder: (context, state) => const AuditLogScreen(),
      ),

      // Phase 3 — Academic Structure
      GoRoute(
        path: RouteNames.academics,
        builder: (context, state) => const AcademicYearsScreen(),
      ),
      GoRoute(
        path: RouteNames.academicStructure,
        builder: (context, state) => const AcademicStructureScreen(),
      ),

      // Phase 4 & 6 — Enrollment
      GoRoute(
        path: RouteNames.enrollment,
        builder: (context, state) => const EnrollmentScreen(),
      ),

      // Phase 7 — Promotion Workflow
      GoRoute(
        path: RouteNames.promotion,
        builder: (context, state) => const PromotionWorkflowScreen(),
      ),

      // Phase 4 — Teacher Assignment Management
      GoRoute(
        path: RouteNames.teacherAssignments,
        builder: (context, state) => const TeacherAssignmentScreen(),
      ),

      // Phase 2 — Role Profiles & Identifiers
      GoRoute(
        path: RouteNames.roleProfiles,
        builder: (context, state) => const RoleProfilesScreen(),
      ),
      GoRoute(
        path: RouteNames.identifierConfigs,
        builder: (context, state) => const IdentifierConfigScreen(),
      ),

      // Phase 5 — Users
      GoRoute(
        path: RouteNames.users,
        builder: (context, state) => const UsersManagementScreen(),
      ),

      // Phase 8 — Fees
      GoRoute(
        path: RouteNames.fees,
        builder: (context, state) => const FeeManagementScreen(),
      ),

      // Phase 9 — Attendance Monitor
      GoRoute(
        path: RouteNames.attendanceMonitor,
        builder: (context, state) => const AttendanceMonitorScreen(),
      ),

      // Phase 10 — Exams & Results
      GoRoute(
        path: RouteNames.examsResults,
        builder: (context, state) => const ExamsResultsScreen(),
      ),

      // Phase 11 — Reports & Analytics
      GoRoute(
        path: RouteNames.reports,
        builder: (context, state) => const ReportsScreen(),
      ),

      // Phase 12 — Communication
      GoRoute(
        path: RouteNames.communication,
        builder: (context, state) => const CommunicationScreen(),
      ),

      // Phase 13 — Document Management
      GoRoute(
        path: RouteNames.documents,
        builder: (context, state) => const DocumentManagementScreen(),
      ),

      // Phase 15 — Bulk Operations
      GoRoute(
        path: RouteNames.bulkOperations,
        builder: (context, state) => const BulkOperationsScreen(),
      ),

      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(state.error?.toString() ?? 'Unknown navigation error'),
      ),
    ),
  );
}