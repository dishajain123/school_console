// lib/domains/providers/dashboard_overview_provider.dart  [Admin Console]

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dashboard/dashboard_overview.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import 'auth_provider.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return DashboardRepository(
    dio,
    AcademicRepository(dio),
    ApprovalRepository(dio),
    AuditRepository(dio),
  );
});

/// Live school snapshot for the dashboard (refresh via invalidation).
final dashboardOverviewProvider =
    FutureProvider.autoDispose<DashboardOverview>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) {
    throw StateError('Not signed in');
  }
  return ref.read(dashboardRepositoryProvider).loadOverview(
        schoolId: user.schoolId,
      );
});
