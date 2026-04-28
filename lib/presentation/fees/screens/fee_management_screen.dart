// lib/presentation/fees/screens/fee_management_screen.dart  [Admin Console]
// Phase 8 — Fee Management Screen.
// Tabs: Fee Structures | Generate Ledger | Record Payment | Fee Analytics
// Accounts Staff: record payments, manage ledgers.
// Admin/Principal: define structures, view analytics, defaulters.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _FeeStructure {
  const _FeeStructure({
    required this.id,
    required this.feeCategory,
    required this.customFeeHead,
    required this.amount,
    required this.dueDate,
    this.standardName,
    this.installmentPlan,
  });

  final String id;
  final String feeCategory;
  final String customFeeHead;
  final double amount;
  final String dueDate;
  final String? standardName;
  final List<dynamic>? installmentPlan;

  factory _FeeStructure.fromJson(Map<String, dynamic> json) => _FeeStructure(
        id: json['id'].toString(),
        feeCategory: json['fee_category']?.toString() ?? '',
        customFeeHead: json['custom_fee_head']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        dueDate: json['due_date']?.toString() ?? '',
        standardName: json['standard']?['name'] as String?,
        installmentPlan: json['installment_plan'] as List<dynamic>?,
      );
}

class _FeeLedger {
  const _FeeLedger({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.status,
    required this.dueDate,
    required this.installmentName,
    required this.studentId,
    required this.feeCategoryLabel,
  });

  final String id;
  final String? studentName;
  final String? admissionNumber;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String status;
  final String dueDate;
  final String installmentName;
  final String studentId;
  final String feeCategoryLabel;

  factory _FeeLedger.fromJson(Map<String, dynamic> json) {
    final total = (json['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (json['paid_amount'] as num?)?.toDouble() ?? 0;
    return _FeeLedger(
      id: json['id'].toString(),
      studentName: json['student']?['user']?['full_name'] as String?,
      admissionNumber: json['student']?['admission_number'] as String?,
      totalAmount: total,
      paidAmount: paid,
      outstandingAmount:
          (json['outstanding_amount'] as num?)?.toDouble() ?? (total - paid),
      status: json['status']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
      installmentName: json['installment_name']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      feeCategoryLabel: json['fee_category']?.toString() ?? '',
    );
  }

  bool get hasOutstanding => outstandingAmount > 0.01;
}

// ── Repository ────────────────────────────────────────────────────────────────

class _FeeRepository {
  _FeeRepository(this._dio);
  final DioClient _dio;

  bool _isUuid(String? value) {
    if (value == null) return false;
    final v = value.trim();
    if (v.isEmpty) return false;
    final re = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return re.hasMatch(v);
  }

  // Structures
  Future<List<Map<String, dynamic>>> listYears(String schoolId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/academic-years',
      queryParameters: {'school_id': schoolId},
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listStandards(
      String schoolId, String academicYearId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/standards',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<_FeeStructure>> listStructures(String standardId,
      {String? academicYearId}) async {
    final resp = await _dio.dio.get<dynamic>(
      '/fees/structures',
      queryParameters: {
        'standard_id': standardId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    final raw = resp.data is List
        ? resp.data as List
        : ((resp.data as Map?)?['items'] as List? ?? []);
    return raw
        .map((e) => _FeeStructure.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> createStructure({
    required String standardId,
    required String academicYearId,
    required String feeCategory,
    required double amount,
    required String dueDate,
    String? customFeeHead,
  }) async {
    await _dio.dio.post<dynamic>(
      '/fees/structures/batch',
      data: {
        'structures': [
          {
            'standard_id': standardId,
            'academic_year_id': academicYearId,
            'fee_category': feeCategory,
            'amount': amount,
            'due_date': dueDate,
            if (customFeeHead != null && customFeeHead.isNotEmpty)
              'custom_fee_head': customFeeHead,
          }
        ],
      },
    );
  }

  Future<Map<String, dynamic>> generateLedger(String standardId,
      {String? academicYearId}) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      '/fees/ledger/generate',
      data: {
        'standard_id': standardId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    return resp.data ?? {};
  }

  // Fee ledger search by standard (for payment recording)
  Future<List<_FeeLedger>> listLedgersByStandard(
      String standardId, String academicYearId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/fees/ledger',
      queryParameters: {
        'standard_id': standardId,
        'academic_year_id': academicYearId,
        'page_size': 100,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items
        .map((e) => _FeeLedger.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> recordPayment({
    required String studentId,
    required String feeLedgerId,
    required double amount,
    required String paymentMode,
    required String paymentDate,
    String? referenceNumber,
  }) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      '/fees/payments',
      data: {
        'student_id': studentId,
        'fee_ledger_id': feeLedgerId,
        'amount': amount,
        'payment_mode': paymentMode,
        'payment_date': paymentDate,
        if (referenceNumber != null && referenceNumber.isNotEmpty)
          'reference_number': referenceNumber,
      },
    );
    return resp.data ?? {};
  }

  // Phase 8: Fee analytics — CORRECT endpoint is /fees/analytics (not /fees/collection-summary)
  Future<Map<String, dynamic>> getFeeAnalytics({
    String? academicYearId,
    String? standardId,
  }) async {
    final safeAcademicYearId = _isUuid(academicYearId) ? academicYearId : null;
    final safeStandardId = _isUuid(standardId) ? standardId : null;
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/fees/analytics',
      queryParameters: {
        if (safeAcademicYearId != null) 'academic_year_id': safeAcademicYearId,
        if (safeStandardId != null) 'standard_id': safeStandardId,
      },
    );
    return resp.data ?? {};
  }

  Future<List<Map<String, dynamic>>> getDefaulters({
    String? academicYearId,
    String? standardId,
  }) async {
    final safeAcademicYearId = _isUuid(academicYearId) ? academicYearId : null;
    final safeStandardId = _isUuid(standardId) ? standardId : null;
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/fees/defaulters',
      queryParameters: {
        if (safeAcademicYearId != null) 'academic_year_id': safeAcademicYearId,
        if (safeStandardId != null) 'standard_id': safeStandardId,
      },
    );
    return ((resp.data?['defaulters'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class FeeManagementScreen extends ConsumerStatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  ConsumerState<FeeManagementScreen> createState() =>
      _FeeManagementScreenState();
}

class _FeeManagementScreenState extends ConsumerState<FeeManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _FeeRepository _repo;

  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];
  List<_FeeStructure> _structures = [];
  List<_FeeLedger> _ledgers = [];

  String? _selectedYearId;
  String? _selectedStandardId;

  bool _loading = false;
  String? _error;
  String? _success;

  // Analytics state
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _defaulters = [];
  bool _analyticsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _repo = _FeeRepository(ref.read(dioClientProvider));
    _loadYears();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  bool get _canEdit {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    final role = user.role.toUpperCase();
    return role == 'PRINCIPAL' ||
        role == 'SUPERADMIN' ||
        (user.permissions.contains('fee:create'));
  }

  String _fmt(double v) =>
      '₹${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final years = await _repo.listYears(_schoolId!);
      setState(() => _years = years);
      final active =
          years.firstWhere((y) => y['is_active'] == true, orElse: () => {});
      if (active.isNotEmpty && _selectedYearId == null) {
        _selectedYearId = active['id']?.toString();
        await _loadStandards();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStandards() async {
    if (_schoolId == null || _selectedYearId == null) return;
    setState(() => _loading = true);
    try {
      final stds = await _repo.listStandards(_schoolId!, _selectedYearId!);
      setState(() {
        _standards = stds;
        _selectedStandardId = null;
        _structures = [];
        _ledgers = [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStructures(String standardId) async {
    setState(() {
      _selectedStandardId = standardId;
      _loading = true;
      _error = null;
    });
    try {
      final structs = await _repo.listStructures(standardId,
          academicYearId: _selectedYearId);
      setState(() => _structures = structs);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadLedgers() async {
    if (_selectedStandardId == null || _selectedYearId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ledgers = await _repo.listLedgersByStandard(
          _selectedStandardId!, _selectedYearId!);
      setState(() => _ledgers = ledgers);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _analyticsLoading = true;
      _error = null;
    });
    try {
      final analytics = await _repo.getFeeAnalytics(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
      );
      final defaulters = await _repo.getDefaulters(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
      );
      setState(() {
        _analytics = analytics;
        _defaulters = defaulters;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _analyticsLoading = false);
    }
  }

  Future<void> _generateLedger() async {
    if (_selectedStandardId == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final result = await _repo.generateLedger(_selectedStandardId!,
          academicYearId: _selectedYearId);
      final created = result['created'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      setState(() =>
          _success = 'Ledger generated: $created created, $skipped skipped.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateStructureDialog() async {
    if (_selectedStandardId == null || _selectedYearId == null) {
      setState(() => _error = 'Please select an academic year and class first.');
      return;
    }
    final amountCtrl = TextEditingController();
    final dueDateCtrl = TextEditingController(
        text:
            '${DateTime.now().year}-12-31');
    final customHeadCtrl = TextEditingController();
    String feeCat = 'TUITION';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Create Fee Structure'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: feeCat,
                  decoration: const InputDecoration(labelText: 'Fee Category'),
                  items: const [
                    'TUITION', 'TRANSPORT', 'LIBRARY', 'LABORATORY',
                    'SPORTS', 'EXAMINATION', 'MISCELLANEOUS'
                  ]
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => feeCat = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: customHeadCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Custom Fee Head (optional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dueDateCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Due Date (YYYY-MM-DD)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                try {
                  await _repo.createStructure(
                    standardId: _selectedStandardId!,
                    academicYearId: _selectedYearId!,
                    feeCategory: feeCat,
                    amount: amount,
                    dueDate: dueDateCtrl.text.trim(),
                    customFeeHead: customHeadCtrl.text.trim().isEmpty
                        ? null
                        : customHeadCtrl.text.trim(),
                  );
                  await _loadStructures(_selectedStandardId!);
                  if (mounted) {
                    setState(() => _success = 'Fee structure created.');
                  }
                } catch (e) {
                  if (mounted) setState(() => _error = e.toString());
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecordPaymentDialog(_FeeLedger ledger) async {
    final amountCtrl =
        TextEditingController(text: ledger.outstandingAmount.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    String paymentMode = 'CASH';
    String paymentDate = DateTime.now().toIso8601String().substring(0, 10);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ledger.studentName ?? 'Student'} (${ledger.admissionNumber ?? '-'})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                    '${ledger.feeCategoryLabel}${ledger.installmentName.isNotEmpty ? ' — ${ledger.installmentName}' : ''}'),
                Text('Outstanding: ${_fmt(ledger.outstandingAmount)}',
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration:
                      const InputDecoration(labelText: 'Payment Mode'),
                  items: const ['CASH', 'CHEQUE', 'ONLINE', 'UPI', 'BANK_TRANSFER', 'CARD']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => paymentMode = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Reference Number (optional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => paymentDate = v,
                  decoration: InputDecoration(
                    labelText: 'Payment Date (YYYY-MM-DD)',
                    hintText: paymentDate,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                try {
                  await _repo.recordPayment(
                    studentId: ledger.studentId,
                    feeLedgerId: ledger.id,
                    amount: amount,
                    paymentMode: paymentMode,
                    paymentDate: paymentDate,
                    referenceNumber: refCtrl.text.trim().isEmpty
                        ? null
                        : refCtrl.text.trim(),
                  );
                  await _loadLedgers();
                  if (mounted) {
                    setState(() => _success =
                        'Payment of ${_fmt(amount)} recorded for ${ledger.studentName ?? 'student'}.');
                  }
                } catch (e) {
                  if (mounted) setState(() => _error = e.toString());
                }
              },
              child: const Text('Record',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Fee Management',
      child: _loading && _years.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Year + Class selectors ───────────────────────────────
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Academic Year',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          value: _selectedYearId,
                          items: _years
                              .map((y) => DropdownMenuItem<String>(
                                    value: y['id']?.toString(),
                                    child: Text(y['name']?.toString() ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedYearId = v);
                            _loadStandards();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          value: _selectedStandardId,
                          items: _standards
                              .map((s) => DropdownMenuItem<String>(
                                    value: s['id']?.toString(),
                                    child: Text(s['name']?.toString() ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) _loadStructures(v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Status messages ──────────────────────────────────────
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
                      child:
                          Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                    ),
                  if (_success != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(_success!,
                          style: TextStyle(color: Colors.green.shade700)),
                    ),

                  // ── Tabs ─────────────────────────────────────────────────
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Fee Structures'),
                      Tab(text: 'Generate Ledger'),
                      Tab(text: 'Record Payment'),
                      Tab(text: 'Fee Analytics'),
                    ],
                    onTap: (i) {
                      if (i == 2 && _ledgers.isEmpty) _loadLedgers();
                      if (i == 3 && _analytics.isEmpty) _loadAnalytics();
                    },
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ── Tab 0: Structures ───────────────────────────────
                        _buildStructuresTab(),
                        // ── Tab 1: Generate Ledger ──────────────────────────
                        _buildLedgerTab(),
                        // ── Tab 2: Record Payment ───────────────────────────
                        _buildPaymentTab(),
                        // ── Tab 3: Fee Analytics ────────────────────────────
                        _buildAnalyticsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Tab 0: Structures ───────────────────────────────────────────────────────

  Widget _buildStructuresTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${_structures.length} structure(s) for selected class',
                style: const TextStyle(color: Colors.grey)),
            const Spacer(),
            if (_canEdit)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Structure'),
                onPressed: _showCreateStructureDialog,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _structures.isEmpty
              ? const Center(
                  child: Text('Select a class to view fee structures.'))
              : SingleChildScrollView(
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(Colors.grey.shade100),
                    columns: const [
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Fee Head')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Due Date')),
                      DataColumn(label: Text('Installments')),
                    ],
                    rows: _structures
                        .map((s) => DataRow(cells: [
                              DataCell(Text(s.feeCategory)),
                              DataCell(Text(s.customFeeHead.isEmpty
                                  ? s.feeCategory
                                  : s.customFeeHead)),
                              DataCell(Text(_fmt(s.amount))),
                              DataCell(Text(s.dueDate)),
                              DataCell(Text(
                                  s.installmentPlan?.length.toString() ?? '—')),
                            ]))
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Tab 1: Generate Ledger ──────────────────────────────────────────────────

  Widget _buildLedgerTab() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Generate fee ledger entries for all enrolled students in the selected class.\n'
            'Existing entries are skipped (idempotent).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.table_chart_outlined),
            label: const Text('Generate Ledger for Selected Class'),
            onPressed:
                (_loading || _selectedStandardId == null) ? null : _generateLedger,
          ),
          if (_selectedStandardId == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Select a class first.',
                  style: TextStyle(color: Colors.orange)),
            ),
        ],
      ),
    );
  }

  // ── Tab 2: Record Payment ───────────────────────────────────────────────────

  Widget _buildPaymentTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
                '${_ledgers.where((l) => l.hasOutstanding).length} outstanding ledger(s)',
                style: const TextStyle(color: Colors.grey)),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: _selectedStandardId != null ? _loadLedgers : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedStandardId == null)
          const Expanded(
            child: Center(
                child: Text('Select a class to load fee ledger entries.')),
          )
        else if (_ledgers.isEmpty && !_loading)
          const Expanded(
            child: Center(
                child: Text(
                    'No ledger entries found. Generate ledger first.')),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Adm. No.')),
                  DataColumn(label: Text('Fee Head')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Paid')),
                  DataColumn(label: Text('Outstanding')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: _ledgers.map((l) {
                  final statusColor = l.status == 'PAID'
                      ? Colors.green
                      : l.status == 'OVERDUE'
                          ? Colors.red
                          : l.status == 'PARTIAL'
                              ? Colors.orange
                              : Colors.grey;
                  return DataRow(cells: [
                    DataCell(Text(l.studentName ?? '-')),
                    DataCell(Text(l.admissionNumber ?? '-')),
                    DataCell(Text(
                        '${l.feeCategoryLabel}${l.installmentName.isNotEmpty ? '\n${l.installmentName}' : ''}')),
                    DataCell(Text(_fmt(l.totalAmount))),
                    DataCell(Text(_fmt(l.paidAmount))),
                    DataCell(Text(_fmt(l.outstandingAmount),
                        style: TextStyle(
                            color: l.hasOutstanding
                                ? Colors.red
                                : Colors.green))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(l.status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    )),
                    DataCell(l.hasOutstanding
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _showRecordPaymentDialog(l),
                            child: const Text('Pay'),
                          )
                        : const Text('—')),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ── Tab 3: Fee Analytics ────────────────────────────────────────────────────

  Widget _buildAnalyticsTab() {
    if (_analyticsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_analytics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Load Fee Analytics'),
              onPressed: _loadAnalytics,
            ),
          ],
        ),
      );
    }

    final summary = _analytics['summary'] as Map<String, dynamic>? ?? {};
    final byClass = _analytics['by_class'] as List<dynamic>? ?? [];
    final totalPaid = (summary['total_paid_amount'] as num?)?.toDouble() ?? 0;
    final totalOutstanding =
        (summary['total_outstanding_amount'] as num?)?.toDouble() ?? 0;
    final defaultersCount = summary['defaulters_count'] ?? 0;
    final pct = (summary['collection_percentage'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _KpiCard(
                  label: 'Collected',
                  value: _fmt(totalPaid),
                  color: Colors.green),
              _KpiCard(
                  label: 'Outstanding',
                  value: _fmt(totalOutstanding),
                  color: Colors.orange),
              _KpiCard(
                  label: 'Defaulters',
                  value: '$defaultersCount',
                  color: Colors.red),
              _KpiCard(
                  label: 'Collection %',
                  value: '${pct.toStringAsFixed(1)}%',
                  color:
                      pct >= 80 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Class-wise Breakdown',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          if (byClass.isEmpty)
            const Text('No class-wise data available.',
                style: TextStyle(color: Colors.grey))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Class')),
                  DataColumn(label: Text('Students')),
                  DataColumn(label: Text('Billed')),
                  DataColumn(label: Text('Collected')),
                  DataColumn(label: Text('Outstanding')),
                  DataColumn(label: Text('Defaulters')),
                ],
                rows: byClass.map((c) {
                  final m = c as Map;
                  return DataRow(cells: [
                    DataCell(Text(m['standard_name']?.toString() ?? '-')),
                    DataCell(Text('${m['student_count'] ?? 0}')),
                    DataCell(Text(_fmt(
                        (m['total_billed_amount'] as num?)?.toDouble() ?? 0))),
                    DataCell(Text(_fmt(
                        (m['total_paid_amount'] as num?)?.toDouble() ?? 0))),
                    DataCell(Text(_fmt(
                        (m['total_outstanding_amount'] as num?)?.toDouble() ?? 0))),
                    DataCell(Text('${m['defaulters_count'] ?? 0}')),
                  ]);
                }).toList(),
              ),
            ),
          const SizedBox(height: 20),
          const Text('Defaulters',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          if (_defaulters.isEmpty)
            const Text('No defaulters found.',
                style: TextStyle(color: Colors.green))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Adm. No.')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Overdue Entries')),
                  DataColumn(label: Text('Total Overdue')),
                  DataColumn(label: Text('Oldest Due')),
                ],
                rows: _defaulters.map((d) {
                  return DataRow(cells: [
                    DataCell(Text(d['admission_number']?.toString() ?? '-')),
                    DataCell(Text(d['student_name']?.toString() ?? '-')),
                    DataCell(Text('${d['overdue_ledgers'] ?? 0}')),
                    DataCell(Text(_fmt(
                        (d['total_overdue_amount'] as num?)?.toDouble() ?? 0))),
                    DataCell(Text(d['oldest_due_date']?.toString() ?? '-')),
                  ]);
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Analytics'),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
    );
  }
}

// ── KPI Card Widget ────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
