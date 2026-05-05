// lib/data/models/dashboard/dashboard_overview.dart  [Admin Console]

import '../academics/academic_year_item.dart';
import '../audit/audit_log.dart';

/// Aggregated snapshot for the signed-in school (staff admin console).
class DashboardOverview {
  const DashboardOverview({
    required this.apiReachable,
    required this.activeYear,
    required this.allYears,
    required this.pendingApprovals,
    required this.onHoldApprovals,
    required this.examsConfigured,
    required this.standardsConfigured,
    required this.recentAudit,
    this.partialErrors = const [],
  });

  final bool apiReachable;
  final AcademicYearItem? activeYear;
  final List<AcademicYearItem> allYears;
  final int pendingApprovals;
  final int onHoldApprovals;
  final int examsConfigured;
  final int standardsConfigured;
  final List<AuditLog> recentAudit;
  final List<String> partialErrors;

  bool get hasActiveYear => activeYear != null;
}
