// lib/presentation/reports/screens/reports_screen.dart  [Admin Console]
// Phase 5: Reports module for PRINCIPAL — attendance, fee collection, enrollment stats.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _ReportStat {
  const _ReportStat({required this.label, required this.value, required this.icon, this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
}

// ── Repository ────────────────────────────────────────────────────────────────

class _ReportsRepository {
  _ReportsRepository(this._dio);
  final DioClient _dio;

  Future<Map<String, dynamic>> getPrincipalDashboard(String schoolId, {String? academicYearId}) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/principal-reports/dashboard',
      queryParameters: {
        'school_id': schoolId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> getFeeCollectionSummary(String schoolId, {String? academicYearId}) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/fees/collection-summary',
      queryParameters: {
        'school_id': schoolId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    return resp.data ?? {};
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _ReportsRepository _repo;

  bool _loading = false;
  String? _error;
  Map<String, dynamic> _dashboardData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repo = _ReportsRepository(ref.read(dioClientProvider));
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _schoolId => ref.read(authControllerProvider).valueOrNull?.schoolId;

  Future<void> _loadDashboard() async {
    if (_schoolId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.getPrincipalDashboard(_schoolId!);
      setState(() => _dashboardData = data);
    } catch (e) {
      // Dashboard endpoint may not exist; show placeholder
      setState(() => _dashboardData = {});
    } finally {
      setState(() => _loading = false);
    }
  }

  List<_ReportStat> _buildStats() {
    return [
      _ReportStat(
        label: 'Total Students',
        value: (_dashboardData['total_students'] ?? '-').toString(),
        icon: Icons.school_outlined,
        color: Colors.blue,
      ),
      _ReportStat(
        label: 'Total Teachers',
        value: (_dashboardData['total_teachers'] ?? '-').toString(),
        icon: Icons.co_present_outlined,
        color: Colors.green,
      ),
      _ReportStat(
        label: 'Avg Attendance',
        value: _dashboardData['avg_attendance_percent'] != null
            ? '${_dashboardData['avg_attendance_percent']}%'
            : '-',
        icon: Icons.check_circle_outline,
        color: Colors.orange,
      ),
      _ReportStat(
        label: 'Pending Approvals',
        value: (_dashboardData['pending_approvals'] ?? '-').toString(),
        icon: Icons.pending_actions_outlined,
        color: Colors.red,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Reports',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Attendance'),
                      Tab(text: 'Fee Collection'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ── Overview ───────────────────────────────────────
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: _buildStats()
                                    .map(
                                      (stat) => SizedBox(
                                        width: 200,
                                        child: Card(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(stat.icon, color: stat.color, size: 32),
                                                const SizedBox(height: 12),
                                                Text(
                                                  stat.value,
                                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(stat.label, style: const TextStyle(color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              if (_dashboardData.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 32),
                                  child: Center(child: Text('Dashboard data not available. Ensure the backend principal-reports endpoint is accessible.')),
                                ),
                            ],
                          ),
                        ),
                        // ── Attendance ─────────────────────────────────────
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Attendance reports are available in the mobile app for principals.'),
                              SizedBox(height: 8),
                              Text('Use the principal dashboard in the mobile app for class-wise breakdown.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        // ── Fee Collection ─────────────────────────────────
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.payments_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Fee collection reports by class and month.'),
                              SizedBox(height: 8),
                              Text('Navigate to the Fees module to view structures and generate ledgers.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}