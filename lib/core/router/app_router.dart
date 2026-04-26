import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_constants.dart';
import '../../presentation/approvals/screens/approval_detail_screen.dart';
import '../../presentation/approvals/screens/approval_queue_screen.dart';
import '../../presentation/audit/screens/audit_log_screen.dart';
import '../../presentation/auth/screens/admin_login_screen.dart';

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
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(state.error?.toString() ?? 'Unknown navigation error'),
      ),
    ),
  );
}
