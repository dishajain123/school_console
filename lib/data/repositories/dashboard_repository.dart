// lib/data/repositories/dashboard_repository.dart  [Admin Console]

import '../../core/logging/crash_reporter.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/academics/academic_year_item.dart';
import '../models/audit/audit_log.dart';
import '../models/dashboard/dashboard_overview.dart';
import 'academic_repository.dart';
import 'approval_repository.dart';
import 'audit_repository.dart';

class DashboardRepository {
  DashboardRepository(this._dio, this._academic, this._approval, this._audit);

  final DioClient _dio;
  final AcademicRepository _academic;
  final ApprovalRepository _approval;
  final AuditRepository _audit;

  Future<DashboardOverview> loadOverview({String? schoolId}) async {
    final partial = <String>[];
    var reachable = false;

    try {
      await _dio.dio.get<Map<String, dynamic>>(ApiConstants.health);
      reachable = true;
    } catch (e, stack) {
      CrashReporter.log(e, stack);
      partial.add('Could not reach health endpoint.');
    }

    List<AcademicYearItem> years = const [];
    try {
      years = await _academic.listYears(schoolId: schoolId);
    } catch (e) {
      partial.add('Academic years: ${_shortError(e)}');
    }

    AcademicYearItem? active;
    for (final y in years) {
      if (y.isActive) {
        active = y;
        break;
      }
    }
    active ??= years.isNotEmpty ? years.first : null;

    var pending = 0;
    var onHold = 0;
    try {
      pending = await _approval.queueTotal(status: 'PENDING_APPROVAL');
    } catch (e) {
      partial.add('Approvals (pending): ${_shortError(e)}');
    }
    try {
      onHold = await _approval.queueTotal(status: 'ON_HOLD');
    } catch (e) {
      partial.add('Approvals (on hold): ${_shortError(e)}');
    }

    var exams = 0;
    if (active != null) {
      try {
        exams = await _countExamsForYear(active.id);
      } catch (e) {
        partial.add('Exams: ${_shortError(e)}');
      }
    }

    var standards = 0;
    final sid = (schoolId ?? '').trim();
    if (active != null && sid.isNotEmpty) {
      try {
        final list = await _academic.listStandards(
          schoolId: sid,
          academicYearId: active.id,
        );
        standards = list.length;
      } catch (e) {
        partial.add('Classes: ${_shortError(e)}');
      }
    }

    var audit = <AuditLog>[];
    try {
      audit = await _audit.list(page: 1, pageSize: 8);
    } catch (e) {
      partial.add('Audit log: ${_shortError(e)}');
    }

    return DashboardOverview(
      apiReachable: reachable,
      activeYear: active,
      allYears: years,
      pendingApprovals: pending,
      onHoldApprovals: onHold,
      examsConfigured: exams,
      standardsConfigured: standards,
      recentAudit: audit,
      partialErrors: partial,
    );
  }

  Future<int> _countExamsForYear(String academicYearId) async {
    final resp = await _dio.dio.get<dynamic>(
      ApiConstants.resultsExams,
      queryParameters: {'academic_year_id': academicYearId},
    );
    final data = resp.data;
    final List<dynamic> raw;
    if (data is List) {
      raw = data;
    } else if (data is Map && data['items'] is List) {
      raw = data['items'] as List<dynamic>;
    } else {
      raw = const [];
    }
    return raw.length;
  }

  static String _shortError(Object e) {
    final s = e.toString();
    if (s.length > 120) return '${s.substring(0, 117)}…';
    return s;
  }
}
