// lib/presentation/reports/screens/reports_screen.dart  [Admin Console]
// Phase 11 — Reporting & Analytics.
// Tabs: Overview | Fee Collection | Detailed Report
// PRINCIPAL / TRUSTEE / SUPERADMIN access.
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
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

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
    return AdminScaffold(
      title: 'Reports & Analytics',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Global Filter Row ─────────────────────────────────────────
            _buildFilterRow(),
            const SizedBox(height: 10),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ),

            // ── Tabs ──────────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Fee Collection'),
                Tab(text: 'Detailed Report'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
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
      spacing: 12,
      runSpacing: 8,
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
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, size: 14),
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
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Load Overview'),
          onPressed: _loadOverview,
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
            spacing: 12,
            runSpacing: 12,
            children: [
              _KpiCard('Student Strength', '$totalStudents',
                  Icons.how_to_reg_outlined, Colors.blueGrey),
              _KpiCard('Fees Collected', _fmt(feesPaid),
                  Icons.payments_outlined, Colors.blue),
              _KpiCard('Avg Results', '${results.toStringAsFixed(1)}%',
                  Icons.analytics_outlined, results >= 50 ? Colors.green : Colors.orange),
              _KpiCard('Students', '$totalStudents',
                  Icons.people_outline, Colors.blueGrey),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Summary Table',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(Colors.grey.shade100),
              columns: rows.first
                  .map((c) => DataColumn(label: Text(c)))
                  .toList(),
              rows: rows.skip(1).map((row) {
                return DataRow(
                    cells: row.map((c) => DataCell(Text(c))).toList());
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
      return Center(
          child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Load Fee Analytics'),
              onPressed: _loadFeeAnalytics));
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
            spacing: 12,
            runSpacing: 12,
            children: [
              _KpiCard('Collected', _fmt(totalPaid),
                  Icons.check_circle_outline, Colors.green),
              _KpiCard('Outstanding', _fmt(totalOut),
                  Icons.pending_outlined, Colors.orange),
              _KpiCard('Collection %', '${pct.toStringAsFixed(1)}%',
                  Icons.bar_chart_outlined,
                  pct >= 80 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red),
              _KpiCard('Defaulters', '$def',
                  Icons.warning_amber_outlined, Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Class-wise Fee Collection',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          if (byClass.isEmpty)
            const Text('No class-wise data.',
                style: TextStyle(color: Colors.grey))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(Colors.grey.shade100),
                columns: ['Class', 'Students', 'Billed', 'Collected',
                    'Outstanding', 'Defaulters', 'Collection %']
                    .map((c) => DataColumn(label: Text(c)))
                    .toList(),
                rows: byClass.map((c) {
                  final cpct = (c['collection_percentage'] as num?)?.toDouble() ?? 0;
                  return DataRow(cells: [
                    DataCell(Text(c['standard_name']?.toString() ?? '-')),
                    DataCell(Text('${c['total_students'] ?? c['student_count'] ?? 0}')),
                    DataCell(Text(_fmt(c['total_billed'] ?? c['total_billed_amount']))),
                    DataCell(Text(_fmt(c['total_paid'] ?? c['total_paid_amount']))),
                    DataCell(Text(_fmt(c['total_outstanding'] ?? c['total_outstanding_amount']))),
                    DataCell(Text('${c['defaulters_count'] ?? 0}')),
                    DataCell(Text('${cpct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: cpct >= 80 ? Colors.green : cpct >= 50 ? Colors.orange : Colors.red,
                            fontWeight: FontWeight.w600))),
                  ]);
                }).toList(),
              ),
            ),
          if (_defaulters.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('${_defaulters.length} Defaulters',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.red)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(Colors.red.shade50),
                columns: ['Adm. No.', 'Name', 'Overdue Entries', 'Total Due', 'Oldest Due']
                    .map((c) => DataColumn(label: Text(c)))
                    .toList(),
                rows: _defaulters.map((d) => DataRow(cells: [
                      DataCell(Text(d['admission_number']?.toString() ?? '-')),
                      DataCell(Text(d['student_name']?.toString() ?? '-')),
                      DataCell(Text('${d['overdue_ledgers'] ?? 0}')),
                      DataCell(Text(_fmt(d['total_overdue_amount']))),
                      DataCell(Text(d['oldest_due_date']?.toString() ?? '-')),
                    ])).toList(),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Text('Metric:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.search, size: 14),
                label: const Text('Load'),
                onPressed: _loadDetails,
              ),
            ],
          ),
        ),
        Expanded(child: _detailsData.isEmpty
            ? const Center(child: Text('Select a metric and click Load.'))
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
          Wrap(spacing: 12, children: [
            _KpiCard('Total Paid',
                _fmt((overall['amount'] as num?)?.toDouble() ?? 0),
                Icons.payments_outlined, Colors.green),
            _KpiCard('Transactions', '${overall['count'] ?? 0}',
                Icons.receipt_outlined, Colors.blue),
          ]),
          const SizedBox(height: 12),
          if (byStudent.isNotEmpty) ...[
            const Text('Per-Student Fees',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: ['Adm. No.', 'Paid', 'Transactions']
                    .map((c) => DataColumn(label: Text(c)))
                    .toList(),
                rows: byStudent.map((s) => DataRow(cells: [
                      DataCell(Text(s['admission_number']?.toString() ?? '-')),
                      DataCell(Text(
                          _fmt((s['paid_amount'] as num?)?.toDouble() ?? 0))),
                      DataCell(Text('${s['transactions'] ?? 0}')),
                    ])).toList(),
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
          Wrap(spacing: 12, children: [
            _KpiCard('Avg %',
                '${((overall['value'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
                Icons.analytics_outlined, Colors.blue),
            _KpiCard('Students', '${overall['numerator'] ?? 0}',
                Icons.person_outline, Colors.green),
            _KpiCard('Entries', '${overall['denominator'] ?? 0}',
                Icons.edit_note_outlined, Colors.blueGrey),
          ]),
          const SizedBox(height: 12),
          if (bySubject.isNotEmpty) ...[
            const Text('Subject-wise Results',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: ['Subject', 'Entries', 'Avg %']
                    .map((c) => DataColumn(label: Text(c)))
                    .toList(),
                rows: bySubject.map((s) {
                  final avg =
                      (s['average_percentage'] as num?)?.toDouble() ?? 0;
                  return DataRow(cells: [
                    DataCell(Text(s['subject_name']?.toString() ?? '-')),
                    DataCell(Text('${s['entries'] ?? 0}')),
                    DataCell(Text('${avg.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: avg >= 50 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600))),
                  ]);
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
