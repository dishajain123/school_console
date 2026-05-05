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
import '../../presentation/dashboard/screens/dashboard_screen.dart';
import '../../presentation/academics/screens/academic_years_screen.dart';
import '../../presentation/academics/screens/academic_structure_screen.dart';
import '../../presentation/enrollment/screens/enrollment_screen.dart';
import '../../presentation/enrollment/screens/lifecycle_management_screen.dart';
import '../../presentation/enrollment/screens/promotion_workflow_screen.dart';
import '../../presentation/teacher_assignments/screens/teacher_assignment_screen.dart';
import '../../presentation/role_profiles/screens/role_profiles_screen.dart';
import '../../presentation/fees/screens/fee_management_screen.dart';
import '../../presentation/results/screens/exams_results_screen.dart';
import '../../presentation/reports/screens/reports_screen.dart';
import '../../presentation/communication/screens/communication_screen.dart';
import '../../presentation/documents/screens/document_management_screen.dart';
import '../../presentation/documents/screens/document_student_detail_screen.dart';
import '../../presentation/settings/screens/settings_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  // Rebuild router when auth state changes so redirects stay in sync.
  ref.watch(authControllerProvider);
  final router = buildRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

GoRouter buildRouter(Ref ref) {

  return GoRouter(
    initialLocation: RouteNames.login,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLoginPage = state.matchedLocation == RouteNames.login;

      // Never block navigation on loading; keep login visible as safe fallback.
      if (authState.isLoading) {
        return isLoginPage ? null : RouteNames.login;
      }
      final isLoggedIn = authState.valueOrNull != null;

      if (!isLoggedIn && !isLoginPage) return RouteNames.login;
      if (isLoggedIn && isLoginPage) return RouteNames.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const AdminLoginScreen(),
      ),

      GoRoute(
        path: RouteNames.dashboard,
        builder: (context, state) => const DashboardScreen(),
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
      GoRoute(
        path: RouteNames.lifecycleManagement,
        builder: (context, state) => const LifecycleManagementScreen(),
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
      // Phase 8 — Fees
      GoRoute(
        path: RouteNames.fees,
        builder: (context, state) => const FeeManagementScreen(),
      ),

      // Phase 10 — Examination
      GoRoute(
        path: RouteNames.examination,
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
      GoRoute(
        path: '${RouteNames.documentStudentDetail}/:studentId',
        builder: (context, state) {
          final id = state.pathParameters['studentId'] ?? '';
          return DocumentStudentDetailScreen(studentId: id);
        },
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
