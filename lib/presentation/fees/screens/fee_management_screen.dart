// lib/presentation/fees/screens/fee_management_screen.dart  [Admin Console]
// Phase 8 — Fee Management Screen (Production-complete rewrite).
// Tabs: Fee Structures | Generate Ledger | Student Ledger | Record Payment | Analytics & Defaulters
// Fixes: dropdown state management, proper API binding, loading states, edit/delete structures,
//        individual student ledger generation, defaulters list, receipt viewing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Local models ──────────────────────────────────────────────────────────────

class _FeeStructure {
  const _FeeStructure({
    required this.id,
    required this.feeCategory,
    required this.customFeeHead,
    required this.amount,
    required this.dueDate,
    this.standardName,
    this.description,
    this.installmentPlan,
  });

  final String id;
  final String feeCategory;
  final String customFeeHead;
  final double amount;
  final String dueDate;
  final String? standardName;
  final String? description;
  final List<dynamic>? installmentPlan;

  factory _FeeStructure.fromJson(Map<String, dynamic> json) => _FeeStructure(
        id: json['id'].toString(),
        feeCategory: json['fee_category']?.toString() ?? '',
        customFeeHead: json['custom_fee_head']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        dueDate: json['due_date']?.toString() ?? '',
        standardName: json['standard']?['name'] as String?,
        description: json['description'] as String?,
        installmentPlan: json['installment_plan'] as List<dynamic>?,
      );

  String get displayLabel =>
      customFeeHead.trim().isNotEmpty ? customFeeHead : feeCategory;
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
    this.standardName,
    this.customFeeHead,
    this.lastPaymentDate,
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
  final String? standardName;
  final String? customFeeHead;
  final String? lastPaymentDate;

  factory _FeeLedger.fromJson(Map<String, dynamic> json) {
    final total = (json['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (json['paid_amount'] as num?)?.toDouble() ?? 0;
    final outstanding = (json['outstanding_amount'] as num?)?.toDouble() ?? (total - paid);
    return _FeeLedger(
      id: json['id'].toString(),
      studentName: json['student']?['user']?['full_name'] as String? ??
          json['student_name'] as String?,
      admissionNumber: json['student']?['admission_number'] as String? ??
          json['admission_number'] as String?,
      totalAmount: total,
      paidAmount: paid,
      outstandingAmount: outstanding,
      status: json['status']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
      installmentName: json['installment_name']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      feeCategoryLabel: json['fee_category']?.toString() ?? '',
      standardName: json['standard_name'] as String?,
      customFeeHead: json['custom_fee_head'] as String?,
      lastPaymentDate: json['last_payment_date'] as String?,
    );
  }

  bool get hasOutstanding => outstandingAmount > 0.01;

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PARTIAL':
        return Colors.orange;
      case 'OVERDUE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get displayLabel {
    final base = customFeeHead?.trim().isNotEmpty == true
        ? customFeeHead!
        : feeCategoryLabel;
    return installmentName.trim().isNotEmpty ? '$base — $installmentName' : base;
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class _FeeRepository {
  _FeeRepository(this._dio);
  final DioClient _dio;

  bool _isUuid(String? value) {
    if (value == null) return false;
    final v = value.trim();
    if (v.isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(v);
  }

  Future<List<Map<String, dynamic>>> listYears(String schoolId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/academic-years',
      queryParameters: {'school_id': schoolId},
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listStandards(String schoolId, String academicYearId) async {
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

  Future<List<_FeeStructure>> listStructures(String standardId, {String? academicYearId}) async {
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
    String? description,
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
            if (description != null && description.isNotEmpty)
              'description': description,
          }
        ],
      },
    );
  }

  Future<void> updateStructure({
    required String structureId,
    double? amount,
    String? dueDate,
    String? description,
  }) async {
    await _dio.dio.patch<dynamic>(
      '/fees/structures/$structureId',
      data: {
        if (amount != null) 'amount': amount,
        if (dueDate != null) 'due_date': dueDate,
        if (description != null) 'description': description,
      },
    );
  }

  Future<void> deleteStructure(String structureId) async {
    await _dio.dio.delete<dynamic>('/fees/structures/$structureId');
  }

  Future<Map<String, dynamic>> generateLedger(String standardId, {String? academicYearId}) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      '/fees/ledger/generate',
      data: {
        'standard_id': standardId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> generateStudentLedger({
    required String studentId,
    required String standardId,
    String? academicYearId,
  }) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      '/fees/ledger/generate-student',
      data: {
        'student_id': studentId,
        'standard_id': standardId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    return resp.data ?? {};
  }

  Future<List<_FeeLedger>> listLedgers({
    String? standardId,
    String? academicYearId,
    String? studentId,
    String? status,
    int page = 1,
    int pageSize = 100,
  }) async {
    final params = <String, dynamic>{
      if (standardId != null && _isUuid(standardId)) 'standard_id': standardId,
      if (academicYearId != null && _isUuid(academicYearId))
        'academic_year_id': academicYearId,
      if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
      if (status != null && status.isNotEmpty) 'status': status,
      'page': page,
      'page_size': pageSize,
    };
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/fees/ledger',
      queryParameters: params,
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
    String? transactionRef,
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
        if (transactionRef != null && transactionRef.isNotEmpty)
          'transaction_ref': transactionRef,
      },
    );
    return resp.data ?? {};
  }

  Future<Map<String, dynamic>> getFeeAnalytics({
    String? academicYearId,
    String? standardId,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/fees/analytics',
      queryParameters: {
        if (_isUuid(academicYearId)) 'academic_year_id': academicYearId,
        if (_isUuid(standardId)) 'standard_id': standardId,
      },
    );
    return resp.data ?? {};
  }

  Future<List<Map<String, dynamic>>> getDefaulters({
    String? academicYearId,
    String? standardId,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/fees/defaulters',
      queryParameters: {
        if (_isUuid(academicYearId)) 'academic_year_id': academicYearId,
        if (_isUuid(standardId)) 'standard_id': standardId,
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
  ConsumerState<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends ConsumerState<FeeManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _FeeRepository _repo;

  // Shared state
  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];
  String? _selectedYearId;
  String? _selectedStandardId;
  bool _loadingMeta = false;
  String? _error;
  String? _success;

  // Tab 0 — Structures
  List<_FeeStructure> _structures = [];
  bool _loadingStructures = false;

  // Tab 1 — Ledger
  bool _loadingLedger = false;

  // Tab 2 — Student Ledger (admin list)
  List<_FeeLedger> _ledgers = [];
  bool _loadingLedgers = false;
  String? _ledgerStatusFilter;
  String? _ledgerStudentSearch;

  // Tab 3 — Analytics & Defaulters
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _defaulters = [];
  bool _analyticsLoading = false;

  static const _feeCats = [
    'TUITION', 'TRANSPORT', 'LIBRARY', 'LABORATORY',
    'SPORTS', 'EXAMINATION', 'MISCELLANEOUS',
  ];

  static const _payModes = [
    'CASH',
    'UPI',
    'ONLINE',
    'CHEQUE',
    'DD',
    'NEFT',
    'RTGS',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _repo = _FeeRepository(ref.read(dioClientProvider));
    _loadMeta();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _schoolId => ref.read(authControllerProvider).valueOrNull?.schoolId;

  bool get _canEdit {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    final role = user.role.toUpperCase();
    return role == 'PRINCIPAL' || role == 'SUPERADMIN' || user.permissions.contains('fee:create');
  }

  String _fmt(double v) =>
      '₹${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  void _setError(String? e) => setState(() { _error = e; _success = null; });
  void _setSuccess(String s) => setState(() { _success = s; _error = null; });

  // ── Meta loading ────────────────────────────────────────────────────────────

  Future<void> _loadMeta() async {
    if (_schoolId == null) return;
    setState(() { _loadingMeta = true; _error = null; });
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
        await _loadStandards(_selectedYearId!);
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() => _loadingMeta = false);
    }
  }

  Future<void> _loadStandards(String yearId) async {
    if (_schoolId == null) return;
    setState(() { _loadingMeta = true; _standards = []; _selectedStandardId = null; });
    try {
      final stds = await _repo.listStandards(_schoolId!, yearId);
      setState(() => _standards = stds);
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() => _loadingMeta = false);
    }
  }

  // ── Tab 0 — Structures ──────────────────────────────────────────────────────

  Future<void> _loadStructures(String standardId) async {
    setState(() {
      _selectedStandardId = standardId;
      _loadingStructures = true;
      _structures = [];
      _error = null;
    });
    try {
      final structs = await _repo.listStructures(standardId, academicYearId: _selectedYearId);
      setState(() => _structures = structs);
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() => _loadingStructures = false);
    }
  }

  // ── Tab 2 — Admin Ledger List ───────────────────────────────────────────────

  Future<void> _loadLedgers() async {
    setState(() { _loadingLedgers = true; _error = null; });
    try {
      final ledgers = await _repo.listLedgers(
        standardId: _selectedStandardId,
        academicYearId: _selectedYearId,
        status: _ledgerStatusFilter?.isEmpty == true ? null : _ledgerStatusFilter,
        pageSize: 200,
      );
      setState(() => _ledgers = ledgers);
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() => _loadingLedgers = false);
    }
  }

  // ── Tab 3 — Analytics ──────────────────────────────────────────────────────

  Future<void> _loadAnalytics() async {
    setState(() { _analyticsLoading = true; _error = null; });
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
      _setError(e.toString());
    } finally {
      setState(() => _analyticsLoading = false);
    }
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  Future<void> _showCreateStructureDialog() async {
    if (_selectedStandardId == null || _selectedYearId == null) {
      _setError('Please select an academic year and class first.');
      return;
    }
    final amountCtrl = TextEditingController();
    final customHeadCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? dueDate;
    String selectedCat = _feeCats.first;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Add Fee Structure'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Fee Category *', border: OutlineInputBorder()),
                    value: selectedCat,
                    items: _feeCats
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) { if (v != null) setDlg(() => selectedCat = v); },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: customHeadCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Custom Label (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Term 1 Tuition',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (₹) *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(dueDate ?? 'Select Due Date *'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDlg(() {
                          dueDate =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) {
                  _setError('Enter a valid amount.');
                  Navigator.pop(ctx);
                  return;
                }
                if (dueDate == null) {
                  _setError('Select a due date.');
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _repo.createStructure(
                    standardId: _selectedStandardId!,
                    academicYearId: _selectedYearId!,
                    feeCategory: selectedCat,
                    amount: amount,
                    dueDate: dueDate!,
                    customFeeHead: customHeadCtrl.text.trim().isEmpty
                        ? null
                        : customHeadCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  );
                  await _loadStructures(_selectedStandardId!);
                  _setSuccess('Fee structure created successfully.');
                } catch (e) {
                  _setError(e.toString());
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditStructureDialog(_FeeStructure structure) async {
    final amountCtrl = TextEditingController(text: structure.amount.toStringAsFixed(2));
    final descCtrl = TextEditingController(text: structure.description ?? '');
    String? dueDate = structure.dueDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Edit — ${structure.displayLabel}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(dueDate ?? 'Select Due Date'),
                  onPressed: () async {
                    final initial = dueDate != null ? DateTime.tryParse(dueDate!) ?? DateTime.now() : DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: initial,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDlg(() {
                        dueDate =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _repo.updateStructure(
                    structureId: structure.id,
                    amount: double.tryParse(amountCtrl.text.trim()),
                    dueDate: dueDate,
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  );
                  await _loadStructures(_selectedStandardId!);
                  _setSuccess('Fee structure updated.');
                } catch (e) {
                  _setError(e.toString());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteStructure(_FeeStructure structure) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Structure'),
        content: Text(
          'Delete "${structure.displayLabel}" (${_fmt(structure.amount)})?\n\n'
          'This will fail if ledger entries already exist for this fee head.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteStructure(structure.id);
      await _loadStructures(_selectedStandardId!);
      _setSuccess('Fee structure deleted.');
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _showRecordPaymentDialog(_FeeLedger ledger) async {
    final amountCtrl = TextEditingController(text: ledger.outstandingAmount.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final txnCtrl = TextEditingController();
    String paymentMode = 'CASH';
    String paymentDate = DateTime.now().toIso8601String().substring(0, 10);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Record Payment'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ledger.studentName ?? 'Student'} (${ledger.admissionNumber ?? '-'})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    ledger.displayLabel,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Outstanding: ${_fmt(ledger.outstandingAmount)}  |  Due: ${ledger.dueDate}',
                    style: TextStyle(
                      color: ledger.status.toUpperCase() == 'OVERDUE' ? Colors.red : Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
                  const Divider(height: 20),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (₹) *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Payment Mode *', border: OutlineInputBorder()),
                    value: paymentMode,
                    items: _payModes
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) { if (v != null) setDlg(() => paymentMode = v); },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: refCtrl,
                    decoration: const InputDecoration(labelText: 'Reference Number', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: txnCtrl,
                    decoration: const InputDecoration(labelText: 'Transaction ID (UPI/Bank)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('Payment Date: $paymentDate'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDlg(() {
                          paymentDate =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) {
                  _setError('Enter a valid amount.');
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _repo.recordPayment(
                    studentId: ledger.studentId,
                    feeLedgerId: ledger.id,
                    amount: amount,
                    paymentMode: paymentMode,
                    paymentDate: paymentDate,
                    referenceNumber: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                    transactionRef: txnCtrl.text.trim().isEmpty ? null : txnCtrl.text.trim(),
                  );
                  await _loadLedgers();
                  _setSuccess('Payment of ${_fmt(amount)} recorded for ${ledger.studentName ?? 'student'}.');
                } catch (e) {
                  _setError(e.toString());
                }
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStudentLedgerGenerateDialog() async {
    if (_selectedStandardId == null || _selectedYearId == null) {
      _setError('Select a class first.');
      return;
    }
    final studentIdCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Ledger for Individual Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the student UUID to generate fee ledger entries from the current class fee structure. '
              'Use this for mid-year admissions or overrides.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: studentIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Student UUID *',
                border: OutlineInputBorder(),
                hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () async {
              final sid = studentIdCtrl.text.trim();
              if (sid.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final result = await _repo.generateStudentLedger(
                  studentId: sid,
                  standardId: _selectedStandardId!,
                  academicYearId: _selectedYearId,
                );
                final c = result['created'] ?? 0;
                final s = result['skipped'] ?? 0;
                _setSuccess('Student ledger: $c created, $s skipped.');
              } catch (e) {
                _setError(e.toString());
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Fee Management',
      child: _loadingMeta && _years.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Year + Class selectors ─────────────────────────────────
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Academic Year',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedYearId,
                          isExpanded: true,
                          items: _years.map((y) => DropdownMenuItem<String>(
                                value: y['id']?.toString(),
                                child: Text(y['name']?.toString() ?? ''),
                              )).toList(),
                          onChanged: _loadingMeta
                              ? null
                              : (v) {
                                  if (v == null || v == _selectedYearId) return;
                                  setState(() { _selectedYearId = v; _structures = []; _ledgers = []; });
                                  ref.read(activeAcademicYearProvider.notifier).setYear(v);
                                  _loadStandards(v);
                                },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedStandardId,
                          isExpanded: true,
                          hint: const Text('Select class'),
                          items: _standards.map((s) => DropdownMenuItem<String>(
                                value: s['id']?.toString(),
                                child: Text(s['name']?.toString() ?? ''),
                              )).toList(),
                          onChanged: _loadingMeta
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  _loadStructures(v);
                                },
                        ),
                      ),
                      if (_loadingMeta)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Status messages ──────────────────────────────────────────
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
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _error = null),
                          ),
                        ],
                      ),
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
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_success!, style: TextStyle(color: Colors.green.shade700))),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _success = null),
                          ),
                        ],
                      ),
                    ),

                  // ── Tabs ───────────────────────────────────────────────────
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Fee Structures'),
                      Tab(text: 'Generate Ledger'),
                      Tab(text: 'Student Ledger'),
                      Tab(text: 'Record Payment'),
                      Tab(text: 'Analytics & Defaulters'),
                    ],
                    onTap: (i) {
                      if (i == 2 && _ledgers.isEmpty && _selectedStandardId != null) {
                        _loadLedgers();
                      }
                      if (i == 4 && _analytics.isEmpty) _loadAnalytics();
                    },
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildStructuresTab(),
                        _buildGenerateLedgerTab(),
                        _buildStudentLedgerTab(),
                        _buildPaymentTab(),
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
    final total = _structures.fold<double>(0, (s, e) => s + e.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_structures.length} structure(s)${total > 0 ? '  |  Total: ${_fmt(total)}' : ''}',
              style: const TextStyle(color: Colors.grey),
            ),
            const Spacer(),
            if (_canEdit && _selectedStandardId != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Fee Head'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                onPressed: _showCreateStructureDialog,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingStructures)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_structures.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No fee structures. Select a class and add fee heads.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _structures.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final s = _structures[i];
                final hasInstallments = s.installmentPlan != null && s.installmentPlan!.isNotEmpty;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: Icon(Icons.receipt_rounded, color: Colors.indigo.shade700, size: 18),
                  ),
                  title: Text(s.displayLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.feeCategory}  •  Due: ${s.dueDate}'),
                      if (s.description != null && s.description!.isNotEmpty)
                        Text(s.description!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (hasInstallments)
                        Text(
                          '${s.installmentPlan!.length} installments',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt(s.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (_canEdit) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                          tooltip: 'Edit',
                          onPressed: () => _showEditStructureDialog(s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDeleteStructure(s),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Tab 1: Generate Ledger ──────────────────────────────────────────────────

  Widget _buildGenerateLedgerTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  Row(children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 6),
                    Text('How Ledger Generation Works',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    '• Select a class and click "Generate Class Ledger" to create fee entries for ALL students in that class.\n'
                    '• Already-existing entries are skipped (idempotent).\n'
                    '• For individual students (mid-year admissions), use "Generate for Individual Student".\n'
                    '• Fee structures must be created first in the "Fee Structures" tab.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_selectedStandardId == null)
            const Text('Select a class from the dropdown above to proceed.',
                style: TextStyle(color: Colors.grey))
          else ...[
            Text('Selected Class: ${_standards.firstWhere(
              (s) => s['id']?.toString() == _selectedStandardId,
              orElse: () => {'name': _selectedStandardId},
            )['name']}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: _loadingLedger
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.group_add_outlined),
              label: const Text('Generate Class Ledger (All Students)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onPressed: _loadingLedger
                  ? null
                  : () async {
                      setState(() => _loadingLedger = true);
                      try {
                        final result = await _repo.generateLedger(
                          _selectedStandardId!,
                          academicYearId: _selectedYearId,
                        );
                        final created = result['created'] ?? 0;
                        final skipped = result['skipped'] ?? 0;
                        _setSuccess('Ledger generated: $created created, $skipped skipped.');
                      } catch (e) {
                        _setError(e.toString());
                      } finally {
                        setState(() => _loadingLedger = false);
                      }
                    },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Individual Student Assignment',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            const Text(
              'Use this for mid-year admissions, class transfers, or individual overrides.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Generate for Individual Student'),
              onPressed: _showStudentLedgerGenerateDialog,
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Student Ledger ───────────────────────────────────────────────────

  Widget _buildStudentLedgerTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_ledgers.length} ledger entries',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(width: 12),
            DropdownButton<String?>(
              value: _ledgerStatusFilter,
              hint: const Text('All Statuses'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
                ...['PENDING', 'PARTIAL', 'PAID', 'OVERDUE']
                    .map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
              ],
              onChanged: (v) {
                setState(() => _ledgerStatusFilter = v);
                if (_selectedStandardId != null) _loadLedgers();
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _selectedStandardId != null ? _loadLedgers : null,
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_selectedStandardId == null)
          const Expanded(
            child: Center(child: Text('Select a class to view ledger entries.', style: TextStyle(color: Colors.grey))),
          )
        else if (_loadingLedgers)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_ledgers.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No ledger entries. Generate the ledger first.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Load Ledger'),
                    onPressed: _loadLedgers,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Adm. No.')),
                  DataColumn(label: Text('Fee Head')),
                  DataColumn(label: Text('Total'), numeric: true),
                  DataColumn(label: Text('Paid'), numeric: true),
                  DataColumn(label: Text('Outstanding'), numeric: true),
                  DataColumn(label: Text('Due Date')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: _ledgers.map((l) {
                  return DataRow(cells: [
                    DataCell(Text(l.studentName ?? '-', style: const TextStyle(fontSize: 13))),
                    DataCell(Text(l.admissionNumber ?? '-')),
                    DataCell(
                      Tooltip(
                        message: l.feeCategoryLabel,
                        child: Text(
                          l.displayLabel,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(_fmt(l.totalAmount))),
                    DataCell(Text(_fmt(l.paidAmount), style: const TextStyle(color: Colors.green))),
                    DataCell(Text(
                      _fmt(l.outstandingAmount),
                      style: TextStyle(color: l.outstandingAmount > 0 ? Colors.orange.shade700 : Colors.grey),
                    )),
                    DataCell(Text(l.dueDate, style: TextStyle(
                      color: l.status.toUpperCase() == 'OVERDUE' ? Colors.red : null,
                      fontSize: 12,
                    ))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: l.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: l.statusColor.withOpacity(0.4)),
                      ),
                      child: Text(l.status, style: TextStyle(color: l.statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    )),
                    DataCell(
                      l.hasOutstanding && _canEdit
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _showRecordPaymentDialog(l),
                              child: const Text('Pay'),
                            )
                          : const Text('—', style: TextStyle(color: Colors.grey)),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ── Tab 3: Record Payment (quick payment search) ────────────────────────────

  Widget _buildPaymentTab() {
    final unpaid = _ledgers.where((l) => l.hasOutstanding).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          color: Colors.orange.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.orange.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing ${unpaid.length} outstanding entries for the selected class. '
                    'Switch to the "Student Ledger" tab for full list with filters.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_selectedStandardId == null)
          const Expanded(child: Center(child: Text('Select a class to record payments.')))
        else if (unpaid.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  const Text('All fees collected! No outstanding entries.'),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: _loadLedgers,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: unpaid.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final l = unpaid[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: l.statusColor.withOpacity(0.15),
                    child: Icon(Icons.person_outline, color: l.statusColor),
                  ),
                  title: Text(
                    '${l.studentName ?? 'Unknown'} (${l.admissionNumber ?? '-'})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${l.displayLabel}  •  Due: ${l.dueDate}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmt(l.outstandingAmount),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.orange),
                          ),
                          Text(l.status, style: TextStyle(color: l.statusColor, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      if (_canEdit)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _showRecordPaymentDialog(l),
                          child: const Text('Pay'),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Tab 4: Analytics & Defaulters ──────────────────────────────────────────

  Widget _buildAnalyticsTab() {
    if (_analyticsLoading) return const Center(child: CircularProgressIndicator());

    if (_analytics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Load Analytics'),
              onPressed: _loadAnalytics,
            ),
          ],
        ),
      );
    }

    final summary = _analytics['summary'] as Map<String, dynamic>? ?? {};
    final byClass = _analytics['by_class'] as List<dynamic>? ?? [];
    final totalBilled = (summary['total_billed_amount'] as num?)?.toDouble() ?? 0;
    final totalPaid = (summary['total_paid_amount'] as num?)?.toDouble() ?? 0;
    final totalOutstanding = (summary['total_outstanding_amount'] as num?)?.toDouble() ?? 0;
    final defaultersCount = summary['defaulters_count'] ?? 0;
    final pct = (summary['collection_percentage'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI Cards ────────────────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _KpiCard(label: 'Total Billed', value: _fmt(totalBilled), color: Colors.indigo),
              _KpiCard(label: 'Collected', value: _fmt(totalPaid), color: Colors.green),
              _KpiCard(label: 'Outstanding', value: _fmt(totalOutstanding), color: Colors.orange),
              _KpiCard(label: 'Defaulters', value: '$defaultersCount', color: Colors.red),
              _KpiCard(
                label: 'Collection %',
                value: '${pct.toStringAsFixed(1)}%',
                color: pct >= 80 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Class-wise Breakdown ─────────────────────────────────────────
          if (byClass.isNotEmpty) ...[
            const Text('Class-wise Breakdown',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            ...byClass.map((c) {
              final cls = c as Map<String, dynamic>;
              final billed = (cls['total_billed'] as num?)?.toDouble() ?? 0;
              final paid = (cls['total_paid'] as num?)?.toDouble() ?? 0;
              final p = billed > 0 ? (paid / billed).clamp(0.0, 1.0) : 0.0;
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
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
                          Text(cls['standard_name']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          if (cls['section'] != null && cls['section'].toString().isNotEmpty)
                            Text(' – ${cls['section']}', style: const TextStyle(color: Colors.grey)),
                          const Spacer(),
                          Text('${(p * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: p >= 0.8 ? Colors.green : p >= 0.5 ? Colors.orange : Colors.red,
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('Billed: ${_fmt(billed)}  ', style: const TextStyle(fontSize: 12)),
                        Text('Paid: ${_fmt(paid)}  ', style: const TextStyle(fontSize: 12, color: Colors.green)),
                        Text(
                          'Defaulters: ${cls['defaulters_count'] ?? 0}',
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            p >= 0.8 ? Colors.green : p >= 0.5 ? Colors.orange : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          // ── Defaulters List ───────────────────────────────────────────────
          if (_defaulters.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 6),
              Text(
                'Defaulters (${_defaulters.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.red),
              ),
            ]),
            const SizedBox(height: 12),
            ...(_defaulters.map((d) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: const Icon(Icons.person_outline, color: Colors.red),
                    ),
                    title: Text(
                      d['student_name']?.toString() ?? 'Unknown Student',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Adm: ${d['admission_number'] ?? '-'}  |  Overdue Entries: ${d['overdue_ledgers']}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmt((d['total_overdue_amount'] as num?)?.toDouble() ?? 0),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: Colors.red, fontSize: 15),
                        ),
                        if (d['oldest_due_date'] != null)
                          Text('Since ${d['oldest_due_date']}',
                              style: const TextStyle(fontSize: 11, color: Colors.red)),
                      ],
                    ),
                  ),
                ))),
          ] else if (!_analyticsLoading && _analytics.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  const Text('No defaulters! All students are within their payment schedule.'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
