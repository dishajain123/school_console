// lib/presentation/bulk/screens/bulk_operations_screen.dart  [Admin Console]
// Phase 15 — Bulk Operations.
// CREATED: this file was missing and only referenced in app_router.dart.
// Integrates all Phase 15 backend endpoints:
//   POST /bulk/students        — bulk student admission (up to 200)
//   POST /bulk/fees            — bulk fee structure assignment
//   GET  /bulk/students/template — CSV template download
//   GET  /bulk/fees/template    — CSV template download
//
// Tab 1 — Bulk Student Admission: paste JSON rows or upload CSV.
//   Displays per-row results (created / skipped / error) after execution.
//   Template download redirects to the backend streaming endpoint via browser.
// Tab 2 — Bulk Fee Assignment: form-based entry for multiple classes.
//   Supports up to 20 fee rows per request, per-row results shown.
// Permissions: Principal, Superadmin, or staff with user:manage / fee:create.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:universal_html/html.dart' as html;

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Result row models ─────────────────────────────────────────────────────────

class _StudentResultRow {
  const _StudentResultRow({
    required this.rowIndex,
    required this.fullName,
    required this.email,
    required this.status,
    this.admissionNumber,
    this.userId,
    this.error,
  });

  final int? rowIndex;
  final String fullName;
  final String email;
  final String status; // created | skipped | error
  final String? admissionNumber;
  final String? userId;
  final String? error;

  factory _StudentResultRow.fromJson(Map<String, dynamic> j) =>
      _StudentResultRow(
        rowIndex: (j['row_index'] as num?)?.toInt(),
        fullName: j['full_name']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        status: j['status']?.toString() ?? 'error',
        admissionNumber: j['admission_number'] as String?,
        userId: j['user_id'] as String?,
        error: j['error'] as String?,
      );

  Color get statusColor {
    switch (status) {
      case 'created':
        return Colors.green;
      case 'skipped':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'created':
        return Icons.check_circle_outline;
      case 'skipped':
        return Icons.skip_next_outlined;
      default:
        return Icons.error_outline;
    }
  }
}

class _FeeResultRow {
  const _FeeResultRow({
    required this.standardId,
    required this.feeCategory,
    required this.status,
    this.structureId,
    this.error,
  });

  final String standardId;
  final String feeCategory;
  final String status;
  final String? structureId;
  final String? error;

  factory _FeeResultRow.fromJson(Map<String, dynamic> j) => _FeeResultRow(
        standardId: j['standard_id']?.toString() ?? '',
        feeCategory: j['fee_category']?.toString() ?? '',
        status: j['status']?.toString() ?? 'error',
        structureId: j['structure_id'] as String?,
        error: j['error'] as String?,
      );

  Color get statusColor {
    switch (status) {
      case 'created':
        return Colors.green;
      case 'skipped':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class _BulkRepository {
  _BulkRepository(this._dio);
  final DioClient _dio;

  // POST /bulk/students
  Future<Map<String, dynamic>> bulkAdmitStudents(
      List<Map<String, dynamic>> rows) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      '/bulk/students',
      data: {'rows': rows},
    );
    return resp.data ?? {};
  }

  // POST /bulk/fees
  Future<Map<String, dynamic>> bulkAssignFees({
    required String academicYearId,
    required List<Map<String, dynamic>> rows,
  }) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      '/bulk/fees',
      data: {'academic_year_id': academicYearId, 'rows': rows},
    );
    return resp.data ?? {};
  }

  // GET /academic-years
  Future<List<Map<String, dynamic>>> listYears(String schoolId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/academic-years',
      queryParameters: {'school_id': schoolId},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // GET /masters/standards
  Future<List<Map<String, dynamic>>> listStandards(
      String schoolId, String yearId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/standards',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': yearId,
      },
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // GET /masters/sections
  Future<List<Map<String, dynamic>>> listSections(
      String schoolId, String standardId, String yearId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/sections',
      queryParameters: {
        'school_id': schoolId,
        'standard_id': standardId,
        'academic_year_id': yearId,
      },
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class BulkOperationsScreen extends ConsumerStatefulWidget {
  const BulkOperationsScreen({super.key});

  @override
  ConsumerState<BulkOperationsScreen> createState() =>
      _BulkOperationsScreenState();
}

class _BulkOperationsScreenState extends ConsumerState<BulkOperationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _BulkRepository _repo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repo = _BulkRepository(ref.read(dioClientProvider));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Bulk Operations',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                    icon: Icon(Icons.people_outline),
                    text: 'Bulk Student Admission'),
                Tab(
                    icon: Icon(Icons.payments_outlined),
                    text: 'Bulk Fee Assignment'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BulkStudentTab(repo: _repo),
                  _BulkFeeTab(repo: _repo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Bulk Student Admission ─────────────────────────────────────────────

class _BulkStudentTab extends ConsumerStatefulWidget {
  const _BulkStudentTab({required this.repo});
  final _BulkRepository repo;

  @override
  ConsumerState<_BulkStudentTab> createState() => _BulkStudentTabState();
}

class _BulkStudentTabState extends ConsumerState<_BulkStudentTab> {
  final _jsonCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _success;
  List<_StudentResultRow> _results = [];
  int _created = 0;
  int _skipped = 0;
  int _errors = 0;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  void _downloadTemplate() {
    final dio = ref.read(dioClientProvider);
    final baseUrl = dio.dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    final url = '$baseUrl/bulk/students/template';
    html.AnchorElement(href: url)
      ..setAttribute('download', 'bulk_student_template.csv')
      ..click();
  }

  Future<void> _submit() async {
    final raw = _jsonCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Paste JSON rows array before submitting.');
      return;
    }
    List<dynamic> rows;
    try {
      rows = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      setState(() => _error = 'Invalid JSON: ${e.toString()}');
      return;
    }
    if (rows.isEmpty) {
      setState(() => _error = 'The rows array is empty.');
      return;
    }
    if (rows.length > 200) {
      setState(() => _error = 'Maximum 200 rows per request.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
      _results = [];
    });

    try {
      final resp = await widget.repo.bulkAdmitStudents(
        rows.map((r) => Map<String, dynamic>.from(r as Map)).toList(),
      );
      final rawResults =
          ((resp['results'] as List?) ?? []).cast<Map<String, dynamic>>();
      final resultRows =
          rawResults.map((r) => _StudentResultRow.fromJson(r)).toList();
      setState(() {
        _results = resultRows;
        _created = (resp['created'] as num?)?.toInt() ?? 0;
        _skipped = (resp['skipped'] as num?)?.toInt() ?? 0;
        _errors = (resp['errors'] as num?)?.toInt() ?? 0;
        _success =
            'Processed ${rows.length} row(s): $_created created, $_skipped skipped, $_errors error(s).';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Instructions card ─────────────────────────────────────────
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'How to use Bulk Student Admission',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Download the CSV template below.\n'
                    '2. Fill in one student per row (max 200 rows).\n'
                    '3. Convert your CSV to a JSON array and paste it in the field below.\n'
                    '    Each row must include: full_name, email, phone, password,\n'
                    '    standard_id, section_id, academic_year_id.\n'
                    '4. Duplicate emails/phones are skipped automatically.\n'
                    '5. Click Submit — results appear row by row below.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text('Download CSV Template'),
                    onPressed: _downloadTemplate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── JSON input ────────────────────────────────────────────────
          const Text(
            'Student Rows (JSON Array)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _jsonCtrl,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  '[\n  {\n    "full_name": "John Doe",\n    "email": "john@example.com",\n    ...\n  }\n]',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 12),

          // ── Error/success messages ────────────────────────────────────
          if (_error != null)
            _StatusBanner(message: _error!, isError: true,
                onDismiss: () => setState(() => _error = null)),
          if (_success != null)
            _StatusBanner(message: _success!, isError: false,
                onDismiss: () => setState(() => _success = null)),

          const SizedBox(height: 8),

          // ── Submit button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file_outlined),
              label:
                  Text(_loading ? 'Processing...' : 'Submit Bulk Admission'),
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          // ── Results ───────────────────────────────────────────────────
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Results',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                _ResultBadge(label: '$_created created', color: Colors.green),
                const SizedBox(width: 6),
                _ResultBadge(label: '$_skipped skipped', color: Colors.orange),
                const SizedBox(width: 6),
                _ResultBadge(label: '$_errors error(s)', color: Colors.red),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_results.length, (i) {
              final r = _results[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                      color: r.statusColor.withOpacity(0.4)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(r.statusIcon,
                      color: r.statusColor, size: 20),
                  title: Text(
                    '${r.rowIndex != null ? '#${r.rowIndex} — ' : ''}${r.fullName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    r.status == 'created'
                        ? 'Created — Admission: ${r.admissionNumber ?? '—'}'
                        : r.status == 'skipped'
                            ? 'Skipped: ${r.error ?? 'Duplicate'}'
                            : 'Error: ${r.error ?? 'Unknown error'}',
                    style: TextStyle(
                        fontSize: 11, color: r.statusColor),
                  ),
                  trailing: r.status == 'created' && r.admissionNumber != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.green.shade200),
                          ),
                          child: Text(
                            r.admissionNumber!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Tab 2: Bulk Fee Assignment ────────────────────────────────────────────────

const _feeCategories = [
  'TUITION',
  'TRANSPORT',
  'LIBRARY',
  'LABORATORY',
  'SPORTS',
  'EXAMINATION',
  'MISCELLANEOUS',
];

class _FeeRow {
  _FeeRow({this.standardId, this.category, this.amount, this.dueDate});
  String? standardId;
  String? category;
  double? amount;
  String? dueDate;
  String? customHead;
}

class _BulkFeeTab extends ConsumerStatefulWidget {
  const _BulkFeeTab({required this.repo});
  final _BulkRepository repo;

  @override
  ConsumerState<_BulkFeeTab> createState() => _BulkFeeTabState();
}

class _BulkFeeTabState extends ConsumerState<_BulkFeeTab> {
  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];

  String? _selectedYearId;
  bool _loadingMeta = false;

  final List<_FeeRow> _feeRows = [_FeeRow()];

  bool _submitting = false;
  String? _error;
  String? _success;
  List<_FeeResultRow> _results = [];
  int _created = 0;
  int _skipped = 0;
  int _errorsCount = 0;

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  void _downloadTemplate() {
    final dio = ref.read(dioClientProvider);
    final baseUrl = dio.dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    final url = '$baseUrl/bulk/fees/template';
    html.AnchorElement(href: url)
      ..setAttribute('download', 'bulk_fee_template.csv')
      ..click();
  }

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() => _loadingMeta = true);
    try {
      final years = await widget.repo.listYears(_schoolId!);
      setState(() => _years = years);
      final active = years.firstWhere(
          (y) => y['is_active'] == true,
          orElse: () => years.isNotEmpty ? years.first : {});
      if (active.isNotEmpty) {
        _selectedYearId = active['id']?.toString();
        await _loadStandards(_selectedYearId!);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingMeta = false);
    }
  }

  Future<void> _loadStandards(String yearId) async {
    if (_schoolId == null) return;
    try {
      final stds = await widget.repo.listStandards(_schoolId!, yearId);
      setState(() => _standards = stds);
    } catch (_) {}
  }

  void _addRow() {
    if (_feeRows.length >= 20) return;
    setState(() => _feeRows.add(_FeeRow()));
  }

  void _removeRow(int i) {
    if (_feeRows.length == 1) return;
    setState(() => _feeRows.removeAt(i));
  }

  Future<void> _submit() async {
    if (_selectedYearId == null) {
      setState(() => _error = 'Select an academic year first.');
      return;
    }
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < _feeRows.length; i++) {
      final row = _feeRows[i];
      if (row.standardId == null ||
          row.category == null ||
          row.amount == null ||
          row.dueDate == null) {
        setState(() =>
            _error = 'Row ${i + 1} is incomplete — fill all required fields.');
        return;
      }
      rows.add({
        'standard_id': row.standardId,
        'fee_category': row.category,
        'amount': row.amount,
        'due_date': row.dueDate,
        if (row.customHead != null && row.customHead!.isNotEmpty)
          'custom_fee_head': row.customHead,
      });
    }

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
      _results = [];
    });

    try {
      final resp = await widget.repo.bulkAssignFees(
        academicYearId: _selectedYearId!,
        rows: rows,
      );
      final rawResults =
          ((resp['results'] as List?) ?? []).cast<Map<String, dynamic>>();
      final resultRows =
          rawResults.map((r) => _FeeResultRow.fromJson(r)).toList();
      setState(() {
        _results = resultRows;
        _created = (resp['created'] as num?)?.toInt() ?? 0;
        _skipped = (resp['skipped'] as num?)?.toInt() ?? 0;
        _errorsCount = (resp['errors'] as num?)?.toInt() ?? 0;
        _success =
            'Processed ${rows.length} fee row(s): $_created created, $_skipped skipped, $_errorsCount error(s).';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Instructions card ─────────────────────────────────────────
          Card(
            elevation: 0,
            color: Colors.orange.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.orange.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'How to use Bulk Fee Assignment',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Select the academic year.\n'
                    '2. Add one row per fee structure (class + category + amount + due date).\n'
                    '3. Duplicate combinations (same class + category + year) are skipped.\n'
                    '4. After creating structures, generate ledger entries in the Fees module.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text('Download CSV Template'),
                    onPressed: _downloadTemplate,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Year selector ─────────────────────────────────────────────
          if (_loadingMeta)
            const LinearProgressIndicator()
          else
            Row(
              children: [
                const Text('Academic Year:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedYearId,
                  hint: const Text('Select year'),
                  items: _years
                      .map((y) => DropdownMenuItem<String>(
                            value: y['id']?.toString(),
                            child: Text(y['name']?.toString() ?? ''),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedYearId = v;
                      _standards = [];
                    });
                    if (v != null) _loadStandards(v);
                  },
                ),
              ],
            ),

          const SizedBox(height: 16),
          const Text('Fee Rows',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 6),

          // ── Fee row builder ───────────────────────────────────────────
          ...List.generate(_feeRows.length, (i) {
            final row = _feeRows[i];
            return _FeeRowCard(
              index: i,
              row: row,
              standards: _standards,
              onChanged: () => setState(() {}),
              onRemove: _feeRows.length > 1 ? () => _removeRow(i) : null,
            );
          }),

          if (_feeRows.length < 20)
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Fee Row'),
              onPressed: _addRow,
            ),

          const SizedBox(height: 12),

          // ── Error / success ───────────────────────────────────────────
          if (_error != null)
            _StatusBanner(
                message: _error!,
                isError: true,
                onDismiss: () => setState(() => _error = null)),
          if (_success != null)
            _StatusBanner(
                message: _success!,
                isError: false,
                onDismiss: () => setState(() => _success = null)),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: Text(
                  _submitting ? 'Processing...' : 'Submit Fee Structures'),
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          // ── Results ───────────────────────────────────────────────────
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Results',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                _ResultBadge(
                    label: '$_created created', color: Colors.green),
                const SizedBox(width: 6),
                _ResultBadge(
                    label: '$_skipped skipped', color: Colors.orange),
                const SizedBox(width: 6),
                _ResultBadge(
                    label: '$_errorsCount error(s)', color: Colors.red),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_results.length, (i) {
              final r = _results[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                      color: r.statusColor.withOpacity(0.4)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    r.status == 'created'
                        ? Icons.check_circle_outline
                        : r.status == 'skipped'
                            ? Icons.skip_next_outlined
                            : Icons.error_outline,
                    color: r.statusColor,
                    size: 20,
                  ),
                  title: Text(
                    '${r.feeCategory} — ${r.standardId}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: r.error != null
                      ? Text(r.error!,
                          style: TextStyle(
                              fontSize: 11, color: r.statusColor))
                      : Text(r.status,
                          style: TextStyle(
                              fontSize: 11, color: r.statusColor)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Fee Row Card widget ───────────────────────────────────────────────────────

class _FeeRowCard extends StatelessWidget {
  const _FeeRowCard({
    required this.index,
    required this.row,
    required this.standards,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final _FeeRow row;
  final List<Map<String, dynamic>> standards;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Row ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red, size: 18),
                    onPressed: onRemove,
                    tooltip: 'Remove row',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // Class
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: row.standardId,
                    decoration: const InputDecoration(
                      labelText: 'Class *',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    items: standards
                        .map((s) => DropdownMenuItem<String>(
                              value: s['id']?.toString(),
                              child: Text(s['name']?.toString() ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) {
                      row.standardId = v;
                      onChanged();
                    },
                  ),
                ),
                // Category
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: row.category,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    items: _feeCategories
                        .map((c) =>
                            DropdownMenuItem<String>(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      row.category = v;
                      onChanged();
                    },
                  ),
                ),
                // Amount
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    initialValue:
                        row.amount != null ? row.amount.toString() : '',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) {
                      row.amount = double.tryParse(v);
                      onChanged();
                    },
                  ),
                ),
                // Due date
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    initialValue: row.dueDate,
                    decoration: const InputDecoration(
                      labelText: 'Due Date * (YYYY-MM-DD)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) {
                      row.dueDate = v.trim().isEmpty ? null : v.trim();
                      onChanged();
                    },
                  ),
                ),
                // Custom head (optional)
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    initialValue: row.customHead,
                    decoration: const InputDecoration(
                      labelText: 'Custom Head (optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) {
                      row.customHead = v.trim().isEmpty ? null : v.trim();
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : Colors.green;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color.shade700,
              size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 13, color: color.shade800))),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 14, color: color.shade400),
          ),
        ],
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}