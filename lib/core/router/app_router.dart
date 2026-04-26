import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_constants.dart';
import '../../presentation/approvals/screens/approval_detail_screen.dart';
import '../../presentation/approvals/screens/approval_queue_screen.dart';
import '../../presentation/audit/screens/audit_log_screen.dart';
import '../../presentation/auth/screens/admin_login_screen.dart';
import '../../presentation/academics/screens/academic_years_screen.dart';
import '../../presentation/role_profiles/screens/identifier_config_screen.dart';
import '../../presentation/role_profiles/screens/role_profiles_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: RouteNames.login,
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const AdminLoginScreen(),
      ),
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
      GoRoute(
        path: RouteNames.audit,
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: RouteNames.academics,
        builder: (context, state) => const AcademicYearsScreen(),
      ),
      GoRoute(
        path: RouteNames.roleProfiles,
        builder: (context, state) => const RoleProfilesScreen(),
      ),
      GoRoute(
        path: RouteNames.identifierConfigs,
        builder: (context, state) => const IdentifierConfigScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(state.error?.toString() ?? 'Unknown navigation error'),
      ),
    ),
  );
}
