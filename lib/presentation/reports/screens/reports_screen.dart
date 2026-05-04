// lib/presentation/reports/screens/reports_screen.dart  [Admin Console]
// Phase 11 — Reporting & Analytics.
// Tabs: Overview | Fee Collection | Detailed Report
// PRINCIPAL / TRUSTEE / STAFF_ADMIN access.
// Export: CSV download via browser for management sharing.
// APIs used:
//   GET /principal-reports/overview      — summary KPIs
//   GET /principal-reports/details       — drill-down with metric/class/section filters
//   GET /fees/analytics                  — fee collection breakdown
//   GET /students + /masters/standards   — student strength by class
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_filter_card.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_table_helpers.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class _ReportsRepository {
  _ReportsRepository(this._dio);
  final DioClient _dio;

  Future<List<Map<String, dynamic>>> listYears(String schoolId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.academicYears,
      queryParameters: {'school_id': schoolId},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listStandards(
      String schoolId, String yearId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.standards,
      queryParameters: {'school_id': schoolId, 'academic_year_id': yearId},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // Phase 11: GET /principal-reports/overview — KPI summary
  Future<Map<String, dynamic>> getOverview({String? yearId}) async {
    try {
      final r = await _dio.dio.get<Map<String, dynamic>>(
        ApiConstants.principalReportsOverview,
        queryParameters: {
          if (yearId != null) 'academic_year_id': yearId,
        },
      );
      return r.data ?? {};
    } catch (_) {
      return {};
    }
  }

  // Phase 11: GET /principal-reports/details — drill-down by metric/class/section
  Future<Map<String, dynamic>> getDetails({
    String? yearId,
    String? metric,
    String? standardId,
    String? section,
  }) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.principalReportsDetails,
      queryParameters: {
        if (yearId != null) 'academic_year_id': yearId,
        if (metric != null) 'metric': metric,
        if (standardId != null) 'standard_id': standardId,
        if (section != null && section.trim().isNotEmpty) 'section': section,
      },
    );
    return r.data ?? {};
  }

  // Phase 11: GET /fees/analytics — fee collection summary
  Future<Map<String, dynamic>> getFeeAnalytics({
    String? yearId,
    String? standardId,
  }) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.feeAnalytics,
      queryParameters: {
        if (yearId != null) 'academic_year_id': yearId,
        if (standardId != null) 'standard_id': standardId,
      },
    );
    return r.data ?? {};
  }

  // Phase 11: student strength — list students per class
  Future<Map<String, dynamic>> getStudentStrength(
      String schoolId, String yearId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.students,
      queryParameters: {
        'academic_year_id': yearId,
        'page': 1,
        'page_size': 1,
      },
    );
    return r.data ?? {};
  }

  Future<List<Map<String, dynamic>>> getDefaulters({String? yearId}) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.feeDefaulters,
      queryParameters: {
        if (yearId != null) 'academic_year_id': yearId,
      },
    );
    return ((r.data?['defaulters'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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

  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];
  String? _selectedYearId;
  String? _filterStandardId;
  String _filterSection = '';

  // Data caches per tab
  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _feeData = {};
  List<Map<String, dynamic>> _defaulters = [];
  Map<String, dynamic> _detailsData = {};
  String _selectedDetailMetric = 'fees_paid';

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repo = _ReportsRepository(ref.read(dioClientProvider));
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _onTabChanged(_tabController.index);
    });
    _loadYears();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  void _resetReportFilters() {
    setState(() {
      _filterStandardId = null;
      _filterSection = '';
      _overview = {};
      _feeData = {};
      _detailsData = {};
      _defaulters = [];
      _error = null;
    });
  }

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() => _loading = true);
    try {
      final years = await _repo.listYears(_schoolId!);
      setState(() => _years = years);
      final preferredYearId = ref.read(activeAcademicYearProvider);
      final preferred = years.firstWhere(
        (y) => y['id']?.toString() == preferredYearId,
        orElse: () => <String, dynamic>{},
      );
      final active = years.firstWhere(
        (y) => y['is_active'] == true,
        orElse: () => years.isNotEmpty ? years.first : <String, dynamic>{},
      );
      final selected = preferred.isNotEmpty ? preferred : active;
      if (selected.isNotEmpty) {
        _selectedYearId = selected['id']?.toString();
        ref.read(activeAcademicYearProvider.notifier).setYear(_selectedYearId);
        await _loadStandards();
        await _loadOverview();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStandards() async {
    if (_schoolId == null || _selectedYearId == null) return;
    try {
      final stds = await _repo.listStandards(_schoolId!, _selectedYearId!);
      setState(() => _standards = stds);
    } catch (_) {}
  }

  Future<void> _onTabChanged(int i) async {
    switch (i) {
      case 0:
        if (_overview.isEmpty) await _loadOverview();
        break;
      case 1:
        if (_feeData.isEmpty) await _loadFeeAnalytics();
        break;
      case 2:
        if (_detailsData.isEmpty) await _loadDetails();
        break;
    }
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ov = await _repo.getOverview(yearId: _selectedYearId);
      setState(() => _overview = ov);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFeeAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.getFeeAnalytics(
          yearId: _selectedYearId, standardId: _filterStandardId);
      final def = await _repo.getDefaulters(yearId: _selectedYearId);
      setState(() {
        _feeData = d;
        _defaulters = def;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.getDetails(
        yearId: _selectedYearId,
        metric: _selectedDetailMetric,
        standardId: _filterStandardId,
        section: _filterSection.isEmpty ? null : _filterSection,
      );
      setState(() => _detailsData = d);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _exportCsv(String title, List<List<String>> rows) {
    final sb = StringBuffer();
    for (final row in rows) {
      sb.writeln(row.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }
    final bytes = utf8.encode(sb.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', '${title}_${DateTime.now().toIso8601String().substring(0, 10)}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _fmt(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return '₹${d.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Reports & analytics',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminPageHeader(
              title: 'Reports & analytics',
              subtitle:
                  'Principal KPIs, fee collection, and drill-down exports. '
                  'Pick year and filters, then Apply to refresh the active tab.',
            ),
            AdminFilterCard(
              onReset: _resetReportFilters,
              child: _buildFilterRow(),
            ),
            const SizedBox(height: AdminSpacing.sm),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                child: Material(
                  color: AdminColors.dangerSurface,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    child: SelectableText(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AdminColors.danger,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Tabs ──────────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: const Color(0x00000000),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Fee Collection'),
                Tab(text: 'Detailed Report'),
              ],
            ),
            const SizedBox(height: AdminSpacing.xs),
            Expanded(
              child: _loading
                  ? const AdminLoadingPlaceholder(
                      message: 'Loading reports…',
                      height: 320,
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildFeeTab(),
                        _buildDetailsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Wrap(
      spacing: AdminSpacing.sm,
      runSpacing: AdminSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
                labelText: 'Academic Year',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            value: _selectedYearId,
            items: _years
                .map((y) => DropdownMenuItem<String>(
                    value: y['id']?.toString(),
                    child: Text(y['name']?.toString() ?? '')))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedYearId = v;
                _overview = {};
                _feeData = {};
                _detailsData = {};
              });
              ref.read(activeAcademicYearProvider.notifier).setYear(v);
              _loadStandards();
            },
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(
                labelText: 'Class (filter)',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            value: _filterStandardId,
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('All Classes')),
              ..._standards.map((s) => DropdownMenuItem<String?>(
                  value: s['id']?.toString(),
                  child: Text(s['name']?.toString() ?? ''))),
            ],
            onChanged: (v) => setState(() => _filterStandardId = v),
          ),
        ),
        SizedBox(
          width: 100,
          child: TextFormField(
            initialValue: _filterSection,
            decoration: const InputDecoration(
                labelText: 'Section',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            onChanged: (v) =>
                setState(() => _filterSection = v.trim().toUpperCase()),
          ),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Apply'),
          onPressed: () {
            final i = _tabController.index;
            setState(() {
              _overview = {};
              _feeData = {};
              _detailsData = {};
            });
            _onTabChanged(i);
          },
        ),
      ],
    );
  }

  // ── Tab 0: Overview ─────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    if (_overview.isEmpty) {
      return AdminEmptyState(
        icon: Icons.dashboard_outlined,
        title: 'Overview not loaded',
        message: 'Fetch KPIs for the selected academic year.',
        action: FilledButton.icon(
          onPressed: _loadOverview,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Load overview'),
        ),
      );
    }

    final feesPaid = (_overview['fees_paid_amount'] as num?)?.toDouble() ?? 0;
    final results = (_overview['results_average_percentage'] as num?)?.toDouble() ?? 0;
    final totalStudents = _overview['student_total_records'] ?? 0;
    final paidTxns = _overview['fees_paid_transactions'] ?? 0;
    final resultStudents = _overview['students_with_results'] ?? 0;
    final resultEntries = _overview['result_entries_count'] ?? 0;

    final rows = [
      ['Metric', 'Value', 'Numerator', 'Denominator/Unit'],
      ['Student Strength', '$totalStudents', '$totalStudents', 'students'],
      ['Fees Paid Amount', _fmt(feesPaid), '$paidTxns', 'transactions'],
      ['Results Average %', '${results.toStringAsFixed(1)}%', '$resultStudents', '$resultEntries'],
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export CSV'),
              onPressed: () => _exportCsv('overview', rows),
            ),
          ),
          Wrap(
            spacing: AdminSpacing.sm,
            runSpacing: AdminSpacing.sm,
            children: [
              _KpiCard('Student Strength', '$totalStudents',
                  Icons.how_to_reg_outlined, AdminColors.textSecondary),
              _KpiCard('Fees Collected', _fmt(feesPaid),
                  Icons.payments_outlined, AdminColors.primaryAction),
              _KpiCard('Avg Results', '${results.toStringAsFixed(1)}%',
                  Icons.analytics_outlined,
                  results >= 50 ? AdminColors.success : const Color(0xFFEA580C)),
              _KpiCard('Students', '$totalStudents',
                  Icons.people_outline, AdminColors.textSecondary),
            ],
          ),
          const SizedBox(height: AdminSpacing.lg),
          const Text('Summary Table',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: AdminSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: adminTableHeadingRowColor(),
              horizontalMargin: AdminSpacing.md,
              columnSpacing: AdminSpacing.lg,
              columns: rows.first
                  .map((c) => DataColumn(label: Text(c)))
                  .toList(),
              rows: rows.skip(1).toList().asMap().entries.map((e) {
                final row = e.value;
                return DataRow(
                  color: adminDataRowColor(e.key),
                  cells: row.map((c) => DataCell(Text(c))).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Fee Collection ───────────────────────────────────────────────────

  Widget _buildFeeTab() {
    if (_feeData.isEmpty) {
      return AdminEmptyState(
        icon: Icons.payments_outlined,
        title: 'Fee analytics not loaded',
        message: 'Load collection breakdown for the selected year and class filter.',
        action: FilledButton.icon(
          onPressed: _loadFeeAnalytics,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Load fee analytics'),
        ),
      );
    }

    final summary = _feeData['summary'] as Map<String, dynamic>? ?? {};
    final byClass = (_feeData['by_class'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final exportRows = [
      ['Class', 'Students', 'Billed', 'Collected', 'Outstanding', 'Defaulters', 'Collection %'],
      ...byClass.map((c) => [
            c['standard_name']?.toString() ?? '-',
            '${c['total_students'] ?? 0}',
            _fmt(c['total_billed'] ?? c['total_billed_amount']),
            _fmt(c['total_paid'] ?? c['total_paid_amount']),
            _fmt(c['total_outstanding'] ?? c['total_outstanding_amount']),
            '${c['defaulters_count'] ?? 0}',
            '${((c['collection_percentage'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
          ]),
    ];

    final totalPaid = (summary['total_paid_amount'] as num?)?.toDouble() ?? 0;
    final totalOut = (summary['total_outstanding_amount'] as num?)?.toDouble() ?? 0;
    final pct = (summary['collection_percentage'] as num?)?.toDouble() ?? 0;
    final def = summary['defaulters_count'] ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export CSV'),
              onPressed: () => _exportCsv('fee_collection', exportRows),
            ),
          ),
          Wrap(
            spacing: AdminSpacing.sm,
            runSpacing: AdminSpacing.sm,
            children: [
              _KpiCard('Collected', _fmt(totalPaid),
                  Icons.check_circle_outline, AdminColors.success),
              _KpiCard('Outstanding', _fmt(totalOut),
                  Icons.pending_outlined, const Color(0xFFEA580C)),
              _KpiCard('Collection %', '${pct.toStringAsFixed(1)}%',
                  Icons.bar_chart_outlined,
                  pct >= 80
                      ? AdminColors.success
                      : pct >= 50
                          ? const Color(0xFFEA580C)
                          : AdminColors.danger),
              _KpiCard('Defaulters', '$def',
                  Icons.warning_amber_outlined, AdminColors.danger),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          const Text('Class-wise Fee Collection',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: AdminSpacing.xs),
          if (byClass.isEmpty)
            Text('No class-wise data.',
                style: TextStyle(color: AdminColors.textSecondary))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: adminTableHeadingRowColor(),
                horizontalMargin: AdminSpacing.md,
                columnSpacing: AdminSpacing.lg,
                columns: ['Class', 'Students', 'Billed', 'Collected',
                    'Outstanding', 'Defaulters', 'Collection %']
                    .map((c) => DataColumn(label: Text(c)))
                    .toList(),
                rows: byClass.asMap().entries.map((e) {
                  final c = e.value;
                  final cpct = (c['collection_percentage'] as num?)?.toDouble() ?? 0;
                  return DataRow(
                    color: adminDataRowColor(e.key),
                    cells: [
                    DataCell(Text(c['standard_name']?.toString() ?? '-')),
                    DataCell(Text('${c['total_students'] ?? c['student_count'] ?? 0}')),
                    DataCell(Text(_fmt(c['total_billed'] ?? c['total_billed_amount']))),
                    DataCell(Text(_fmt(c['total_paid'] ?? c['total_paid_amount']))),
                    DataCell(Text(_fmt(c['total_outstanding'] ?? c['total_outstanding_amount']))),
                    DataCell(Text('${c['defaulters_count'] ?? 0}')),
                    DataCell(Text('${cpct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: cpct >= 80
                                ? AdminColors.success
                                : cpct >= 50
                                    ? const Color(0xFFEA580C)
                                    : AdminColors.danger,
                            fontWeight: FontWeight.w600))),
                  ],
                  );
                }).toList(),
              ),
            ),
          if (_defaulters.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('${_defaulters.length} Defaulters',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AdminColors.danger)),
            const SizedBox(height: AdminSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(AdminColors.dangerSurface),
                horizontalMargin: AdminSpacing.md,
                columnSpacing: AdminSpacing.lg,
                columns: ['Adm. No.', 'Name', 'Overdue Entries', 'Total Due', 'Oldest Due']
                    .map((c) => DataColumn(label: Text(c)))
                    .toList(),
                rows: _defaulters.asMap().entries.map((e) {
                  final d = e.value;
                  return DataRow(
                    color: adminDataRowColor(e.key),
                    cells: [
                      DataCell(Text(d['admission_number']?.toString() ?? '-')),
                      DataCell(Text(d['student_name']?.toString() ?? '-')),
                      DataCell(Text('${d['overdue_ledgers'] ?? 0}')),
                      DataCell(Text(_fmt(d['total_overdue_amount']))),
                      DataCell(Text(d['oldest_due_date']?.toString() ?? '-')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Detailed Report ──────────────────────────────────────────────────

  Widget _buildDetailsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AdminSpacing.xs),
          child: Row(
            children: [
              const Text('Metric:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: AdminSpacing.xs),
              DropdownButton<String>(
                value: _selectedDetailMetric,
                items: const [
                  DropdownMenuItem(
                      value: 'fees_paid', child: Text('Fees Paid')),
                  DropdownMenuItem(
                      value: 'results', child: Text('Results')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedDetailMetric = v;
                      _detailsData = {};
                    });
                  }
                },
              ),
              const SizedBox(width: AdminSpacing.xs),
              FilledButton.icon(
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Load'),
                onPressed: _loadDetails,
              ),
            ],
          ),
        ),
        Expanded(
            child: _detailsData.isEmpty
                ? const AdminEmptyState(
                    icon: Icons.table_chart_outlined,
                    title: 'No detail loaded',
                    message: 'Choose Fees paid or Results, then Load.',
                  )
                : SingleChildScrollView(child: _buildDetailBody())),
      ],
    );
  }

  Widget _buildDetailBody() {
    // Fees Paid Detail
    if (_selectedDetailMetric == 'fees_paid') {
      final byStudent = (_detailsData['fees_by_student'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final overall = _detailsData['fees_paid'] as Map? ?? {};
      final exportRows = [
        ['Admission Number', 'Paid Amount', 'Transactions'],
        ...byStudent.map((s) => [
              s['admission_number']?.toString() ?? '-',
              _fmt((s['paid_amount'] as num?)?.toDouble() ?? 0),
              '${s['transactions'] ?? 0}',
            ]),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export CSV'),
              onPressed: () => _exportCsv('fees_paid_detail', exportRows),
            ),
          ),
          Wrap(spacing: AdminSpacing.sm, children: [
            _KpiCard('Total Paid',
                _fmt((overall['amount'] as num?)?.toDouble() ?? 0),
                Icons.payments_outlined, AdminColors.success),
            _KpiCard('Transactions', '${overall['count'] ?? 0}',
                Icons.receipt_outlined, AdminColors.primaryAction),
          ]),
          const SizedBox(height: AdminSpacing.sm),
          if (byStudent.isNotEmpty) ...[
            const Text('Per-Student Fees',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: adminTableHeadingRowColor(),
                horizontalMargin: AdminSpacing.md,
                columnSpacing: AdminSpacing.lg,
                columns: ['Adm. No.', 'Paid', 'Transactions']
                    .map((c) => DataColumn(label: Text(c)))
                    .toList(),
                rows: byStudent.asMap().entries.map((e) {
                  final s = e.value;
                  return DataRow(
                    color: adminDataRowColor(e.key),
                    cells: [
                      DataCell(Text(s['admission_number']?.toString() ?? '-')),
                      DataCell(Text(
                          _fmt((s['paid_amount'] as num?)?.toDouble() ?? 0))),
                      DataCell(Text('${s['transactions'] ?? 0}')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      );
    }

    // Results Detail
    if (_selectedDetailMetric == 'results') {
      final bySubject = (_detailsData['results_by_subject'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final overall = _detailsData['results'] as Map? ?? {};
      final exportRows = [
        ['Subject', 'Entries', 'Average Percentage'],
        ...bySubject.map((s) => [
              s['subject_name']?.toString() ?? '-',
              '${s['entries'] ?? 0}',
              '${((s['average_percentage'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
            ]),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export CSV'),
              onPressed: () => _exportCsv('results_detail', exportRows),
            ),
          ),
          Wrap(spacing: AdminSpacing.sm, children: [
            _KpiCard('Avg %',
                '${((overall['value'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
                Icons.analytics_outlined, AdminColors.primaryAction),
            _KpiCard('Students', '${overall['numerator'] ?? 0}',
                Icons.person_outline, AdminColors.success),
            _KpiCard('Entries', '${overall['denominator'] ?? 0}',
                Icons.edit_note_outlined, AdminColors.textSecondary),
          ]),
          const SizedBox(height: AdminSpacing.sm),
          if (bySubject.isNotEmpty) ...[
            const Text('Subject-wise Results',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: adminTableHeadingRowColor(),
                horizontalMargin: AdminSpacing.md,
                columnSpacing: AdminSpacing.lg,
                columns: ['Subject', 'Entries', 'Avg %']
                    .map((c) => DataColumn(label: Text(c)))
                    .toList(),
                rows: bySubject.asMap().entries.map((e) {
                  final s = e.value;
                  final avg =
                      (s['average_percentage'] as num?)?.toDouble() ?? 0;
                  return DataRow(
                    color: adminDataRowColor(e.key),
                    cells: [
                    DataCell(Text(s['subject_name']?.toString() ?? '-')),
                    DataCell(Text('${s['entries'] ?? 0}')),
                    DataCell(Text('${avg.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: avg >= 50 ? AdminColors.success : AdminColors.danger,
                            fontWeight: FontWeight.w600))),
                  ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      );
    }

    return const Text('Unknown metric.');
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(AdminSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AdminSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AdminColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
