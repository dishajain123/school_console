// lib/presentation/fees/screens/fee_management_screen.dart  [Admin Console]
// Rewritten: class-wise student fee view, one row per student, parent info,
// payment cycle selection, mark-as-paid, auto-overdue, mode of payment.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local models
// ─────────────────────────────────────────────────────────────────────────────

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

class _InstallmentRow {
  const _InstallmentRow({
    required this.ledgerId,
    required this.feeHead,
    required this.installmentName,
    required this.dueDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.status,
    this.lastPaymentDate,
  });

  final String ledgerId;
  final String feeHead;
  final String installmentName;
  final String? dueDate;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String status;
  final String? lastPaymentDate;

  String get displayLabel => installmentName.trim().isNotEmpty
      ? '$feeHead — $installmentName'
      : feeHead;

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
        return Colors.blueGrey;
    }
  }

  factory _InstallmentRow.fromJson(Map<String, dynamic> json) =>
      _InstallmentRow(
        ledgerId: json['ledger_id']?.toString() ?? '',
        feeHead: json['fee_head']?.toString() ?? '',
        installmentName: json['installment_name']?.toString() ?? '',
        dueDate: json['due_date']?.toString(),
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
        outstandingAmount:
            (json['outstanding_amount'] as num?)?.toDouble() ?? 0,
        status: json['status']?.toString() ?? 'PENDING',
        lastPaymentDate: json['last_payment_date']?.toString(),
      );
}

class _StudentFeeRow {
  const _StudentFeeRow({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.standardName,
    required this.section,
    required this.parentName,
    required this.parentPhone,
    required this.parentEmail,
    required this.totalBilled,
    required this.totalPaid,
    required this.totalOutstanding,
    required this.hasOverdue,
    required this.installments,
  });

  final String studentId;
  final String? studentName;
  final String? admissionNumber;
  final String? standardName;
  final String? section;
  final String? parentName;
  final String? parentPhone;
  final String? parentEmail;
  final double totalBilled;
  final double totalPaid;
  final double totalOutstanding;
  final bool hasOverdue;
  final List<_InstallmentRow> installments;

  factory _StudentFeeRow.fromJson(Map<String, dynamic> json) {
    final rawInst = json['installments'] as List<dynamic>? ?? [];
    return _StudentFeeRow(
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name'] as String?,
      admissionNumber: json['admission_number'] as String?,
      standardName: json['standard_name'] as String?,
      section: json['section'] as String?,
      parentName: json['parent_name'] as String?,
      parentPhone: json['parent_phone'] as String?,
      parentEmail: json['parent_email'] as String?,
      totalBilled: (json['total_billed'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0,
      totalOutstanding: (json['total_outstanding'] as num?)?.toDouble() ?? 0,
      hasOverdue: json['has_overdue'] as bool? ?? false,
      installments: rawInst
          .map(
            (e) =>
                _InstallmentRow.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────────────────────────────────────

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

  Future<List<Map<String, dynamic>>> listStandards(
    String schoolId,
    String academicYearId,
  ) async {
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

  Future<List<_FeeStructure>> listStructures(
    String standardId, {
    String? academicYearId,
  }) async {
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
    List<Map<String, dynamic>>? installmentPlan,
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
            if (installmentPlan != null && installmentPlan.isNotEmpty)
              'installment_plan': installmentPlan,
          },
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

  Future<Map<String, dynamic>> generateLedger(
    String standardId, {
    String? academicYearId,
  }) async {
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

  /// New: class-wise student fee summary — one row per student
  Future<Map<String, dynamic>> listClassFeeStudents({
    required String standardId,
    String? academicYearId,
    String? status,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/fees/ledger/class-students',
      queryParameters: {
        'standard_id': standardId,
        if (_isUuid(academicYearId)) 'academic_year_id': academicYearId,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return resp.data ?? {};
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

// ─────────────────────────────────────────────────────────────────────────────
// FeeManagementScreen — Main screen widget
// ─────────────────────────────────────────────────────────────────────────────

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
  String? _selectedYearId;
  String? _selectedStandardId;
  String? _statusFilter;

  // Tab data
  List<_StudentFeeRow> _students = [];
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _defaulters = [];

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repo = _FeeRepository(ref.read(dioClientProvider));
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _onTabChanged(_tabController.index);
    });
    _loadInit();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  Future<void> _loadInit() async {
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
      setState(() {
        _standards = stds;
        if (_selectedStandardId == null && stds.isNotEmpty) {
          _selectedStandardId = stds.first['id']?.toString();
        }
      });
      await _onTabChanged(_tabController.index);
    } catch (_) {}
  }

  Future<void> _onTabChanged(int i) async {
    switch (i) {
      case 0:
        await _loadStudents();
        break;
      case 1:
        await _loadAnalytics();
        break;
      case 2:
        await _loadDefaulters();
        break;
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedStandardId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.listClassFeeStudents(
        standardId: _selectedStandardId!,
        academicYearId: _selectedYearId,
        status: _statusFilter,
      );
      final rawStudents = data['items'] as List<dynamic>? ?? [];
      setState(() {
        _students = rawStudents
            .map(
              (e) =>
                  _StudentFeeRow.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.getFeeAnalytics(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
      );
      setState(() => _analytics = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadDefaulters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.getDefaulters(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
      );
      setState(() => _defaulters = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _fmt(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return '₹${d.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  Future<void> _recordPaymentForStudent(_StudentFeeRow student) async {
    final payableInstallments = student.installments
        .where((i) => i.hasOutstanding && i.ledgerId.isNotEmpty)
        .toList();
    if (payableInstallments.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No outstanding installments for this student.'),
        ),
      );
      return;
    }

    _InstallmentRow selected = payableInstallments.first;
    final amountCtrl = TextEditingController(
      text: selected.outstandingAmount.toStringAsFixed(2),
    );
    final referenceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMode = 'CASH';

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                'Record Payment • ${student.studentName ?? student.admissionNumber ?? 'Student'}',
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selected.ledgerId,
                        decoration: const InputDecoration(
                          labelText: 'Installment',
                          border: OutlineInputBorder(),
                        ),
                        items: payableInstallments
                            .map(
                              (i) => DropdownMenuItem<String>(
                                value: i.ledgerId,
                                child: Text(
                                  '${i.displayLabel} • Due ${_fmt(i.outstandingAmount)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          final match = payableInstallments.firstWhere(
                            (i) => i.ledgerId == v,
                          );
                          setDialogState(() {
                            selected = match;
                            amountCtrl.text = selected.outstandingAmount
                                .toStringAsFixed(2);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: paymentMode,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                          DropdownMenuItem(
                            value: 'CHEQUE',
                            child: Text('Cheque'),
                          ),
                          DropdownMenuItem(
                            value: 'ONLINE',
                            child: Text('Online'),
                          ),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                          DropdownMenuItem(value: 'NEFT', child: Text('NEFT')),
                          DropdownMenuItem(value: 'RTGS', child: Text('RTGS')),
                          DropdownMenuItem(
                            value: 'DD',
                            child: Text('Demand Draft'),
                          ),
                          DropdownMenuItem(
                            value: 'OTHER',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => paymentMode = v ?? 'CASH'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: referenceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reference No. (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSubmit != true) return;

    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid positive amount.')),
      );
      return;
    }
    if (amount > selected.outstandingAmount + 0.01) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount cannot exceed outstanding ${_fmt(selected.outstandingAmount)}.',
          ),
        ),
      );
      return;
    }

    try {
      setState(() => _loading = true);
      final today = DateTime.now();
      final paymentDate =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await _repo.recordPayment(
        studentId: student.studentId,
        feeLedgerId: selected.ledgerId,
        amount: amount,
        paymentMode: paymentMode,
        paymentDate: paymentDate,
        referenceNumber: referenceCtrl.text.trim().isEmpty
            ? null
            : referenceCtrl.text.trim(),
        transactionRef: notesCtrl.text.trim().isEmpty
            ? null
            : notesCtrl.text.trim(),
      );
      await _loadStudents();
      await _loadAnalytics();
      await _loadDefaulters();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update payment: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Fee Management',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Students'),
                Tab(text: 'Analytics'),
                Tab(text: 'Defaulters'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildStudentsTab(),
                        _buildAnalyticsTab(),
                        _buildDefaultersTab(),
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
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _selectedYearId,
            items: _years
                .map(
                  (y) => DropdownMenuItem<String>(
                    value: y['id']?.toString(),
                    child: Text(y['name']?.toString() ?? ''),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedYearId = v;
                _students = [];
                _analytics = {};
                _defaulters = [];
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
              labelText: 'Class',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _selectedStandardId,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Classes'),
              ),
              ..._standards.map(
                (s) => DropdownMenuItem<String?>(
                  value: s['id']?.toString(),
                  child: Text(s['name']?.toString() ?? ''),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedStandardId = v),
          ),
        ),
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _statusFilter,
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('All')),
              DropdownMenuItem<String?>(
                value: 'PENDING',
                child: Text('Pending'),
              ),
              DropdownMenuItem<String?>(
                value: 'PARTIAL',
                child: Text('Partial'),
              ),
              DropdownMenuItem<String?>(value: 'PAID', child: Text('Paid')),
              DropdownMenuItem<String?>(
                value: 'OVERDUE',
                child: Text('Overdue'),
              ),
            ],
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Apply'),
          onPressed: () {
            final i = _tabController.index;
            setState(() {
              _students = [];
              _analytics = {};
              _defaulters = [];
            });
            _onTabChanged(i);
          },
        ),
      ],
    );
  }

  // ── Tab 0: Students ─────────────────────────────────────────────────────────

  Widget _buildStudentsTab() {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a class and click Apply to load students.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Load Students'),
              onPressed: _loadStudents,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        columns: const [
          DataColumn(label: Text('Student')),
          DataColumn(label: Text('Adm. No.')),
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('Parent')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Billed')),
          DataColumn(label: Text('Paid')),
          DataColumn(label: Text('Outstanding')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Action')),
        ],
        rows: _students.map((s) {
          final statusColor = s.hasOverdue
              ? Colors.red
              : s.totalOutstanding > 0
              ? Colors.orange
              : Colors.green;
          final statusLabel = s.hasOverdue
              ? 'Overdue'
              : s.totalOutstanding > 0
              ? 'Partial'
              : 'Paid';
          return DataRow(
            cells: [
              DataCell(Text(s.studentName ?? s.admissionNumber ?? '-')),
              DataCell(Text(s.admissionNumber ?? '-')),
              DataCell(
                Text(
                  '${s.standardName ?? ''} ${s.section != null ? '(${s.section})' : ''}'
                      .trim(),
                ),
              ),
              DataCell(Text(s.parentName ?? '-')),
              DataCell(Text(s.parentPhone ?? '-')),
              DataCell(Text(_fmt(s.totalBilled))),
              DataCell(Text(_fmt(s.totalPaid))),
              DataCell(Text(_fmt(s.totalOutstanding))),
              DataCell(
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(
                ElevatedButton.icon(
                  onPressed: s.installments.any((i) => i.hasOutstanding)
                      ? () => _recordPaymentForStudent(s)
                      : null,
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Update'),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Tab 1: Analytics ────────────────────────────────────────────────────────

  Widget _buildAnalyticsTab() {
    if (_analytics.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Load Analytics'),
          onPressed: _loadAnalytics,
        ),
      );
    }

    final summary = _analytics['summary'] as Map<String, dynamic>? ?? {};
    final byClass = (_analytics['by_class'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final byStatus = (_analytics['by_status'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final byMode = (_analytics['by_payment_mode'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final totalPaid = (summary['total_paid_amount'] as num?)?.toDouble() ?? 0;
    final totalOut =
        (summary['total_outstanding_amount'] as num?)?.toDouble() ?? 0;
    final pct = (summary['collection_percentage'] as num?)?.toDouble() ?? 0;
    final def = summary['defaulters_count'] ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _KpiCard(
                'Collected',
                _fmt(totalPaid),
                Icons.check_circle_outline,
                Colors.green,
              ),
              _KpiCard(
                'Outstanding',
                _fmt(totalOut),
                Icons.pending_outlined,
                Colors.orange,
              ),
              _KpiCard(
                'Collection %',
                '${pct.toStringAsFixed(1)}%',
                Icons.bar_chart_outlined,
                pct >= 80
                    ? Colors.green
                    : pct >= 50
                    ? Colors.orange
                    : Colors.red,
              ),
              _KpiCard(
                'Defaulters',
                '$def',
                Icons.warning_amber_outlined,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Collection progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Collection Rate',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: pct >= 80
                            ? Colors.green
                            : pct >= 50
                            ? Colors.orange
                            : Colors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    pct >= 80
                        ? Colors.green
                        : pct >= 50
                        ? Colors.orange
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Class-wise breakdown
          if (byClass.isNotEmpty) ...[
            const Text(
              'Class-wise Collection',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Class')),
                  DataColumn(label: Text('Students')),
                  DataColumn(label: Text('Billed')),
                  DataColumn(label: Text('Collected')),
                  DataColumn(label: Text('Outstanding')),
                  DataColumn(label: Text('Defaulters')),
                  DataColumn(label: Text('Collection %')),
                ],
                rows: byClass.map((c) {
                  final cpct =
                      (c['collection_percentage'] as num?)?.toDouble() ?? 0;
                  return DataRow(
                    cells: [
                      DataCell(Text(c['standard_name']?.toString() ?? '-')),
                      DataCell(
                        Text(
                          '${c['total_students'] ?? c['student_count'] ?? 0}',
                        ),
                      ),
                      DataCell(
                        Text(
                          _fmt(c['total_billed'] ?? c['total_billed_amount']),
                        ),
                      ),
                      DataCell(
                        Text(_fmt(c['total_paid'] ?? c['total_paid_amount'])),
                      ),
                      DataCell(
                        Text(
                          _fmt(
                            c['total_outstanding'] ??
                                c['total_outstanding_amount'],
                          ),
                        ),
                      ),
                      DataCell(Text('${c['defaulters_count'] ?? 0}')),
                      DataCell(
                        Text(
                          '${cpct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: cpct >= 80
                                ? Colors.green
                                : cpct >= 50
                                ? Colors.orange
                                : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Status breakdown
          if (byStatus.isNotEmpty) ...[
            const Text(
              'By Status',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...byStatus.map((s) {
              final st = (s['status'] as String? ?? '').toUpperCase();
              final color = st == 'PAID'
                  ? Colors.green
                  : st == 'PARTIAL'
                  ? Colors.orange
                  : st == 'OVERDUE'
                  ? Colors.red
                  : Colors.blueGrey;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      st,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text('${s['ledgers'] ?? 0} ledgers'),
                    const SizedBox(width: 16),
                    Text(_fmt(s['paid_amount'])),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Payment mode breakdown
          if (byMode.isNotEmpty) ...[
            const Text(
              'By Payment Mode',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...byMode.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payment_outlined,
                      size: 16,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (m['payment_mode'] as String? ?? '').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text('${m['transactions'] ?? 0} txns'),
                    const SizedBox(width: 16),
                    Text(_fmt(m['amount'])),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Defaulters ───────────────────────────────────────────────────────

  Widget _buildDefaultersTab() {
    if (_defaulters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            const Text('No defaulters found.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: _loadDefaulters,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
        columns: const [
          DataColumn(label: Text('Adm. No.')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Overdue Entries')),
          DataColumn(label: Text('Total Due')),
          DataColumn(label: Text('Oldest Due Date')),
        ],
        rows: _defaulters
            .map(
              (d) => DataRow(
                cells: [
                  DataCell(Text(d['admission_number']?.toString() ?? '-')),
                  DataCell(Text(d['student_name']?.toString() ?? '-')),
                  DataCell(Text('${d['overdue_ledgers'] ?? 0}')),
                  DataCell(Text(_fmt(d['total_overdue_amount']))),
                  DataCell(Text(d['oldest_due_date']?.toString() ?? '-')),
                ],
              ),
            )
            .toList(),
      ),
    );
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
