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
    required this.studentPhone,
    required this.paymentCycle,
    required this.status,
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
  final String? studentPhone;
  final String paymentCycle;
  final String status;
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
      studentPhone: json['student_phone'] as String?,
      paymentCycle: json['payment_cycle']?.toString() ?? 'UNASSIGNED',
      status: json['status']?.toString() ?? 'PENDING',
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
  static const List<String> feeCategories = [
    'TUITION',
    'TRANSPORT',
    'LIBRARY',
    'LABORATORY',
    'SPORTS',
    'EXAMINATION',
    'MISCELLANEOUS',
  ];

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

  Future<List<Map<String, dynamic>>> listSections({
    required String schoolId,
    required String academicYearId,
    required String standardId,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/sections',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'standard_id': standardId,
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

  Future<void> createStructuresBatch({
    required List<Map<String, dynamic>> structures,
  }) async {
    await _dio.dio.post<dynamic>(
      '/fees/structures/batch',
      data: {'structures': structures},
    );
  }

  Future<void> updateStructure({
    required String structureId,
    double? amount,
    String? dueDate,
    String? description,
    bool? applyToAllClasses,
  }) async {
    await _dio.dio.patch<dynamic>(
      '/fees/structures/$structureId',
      data: {
        if (amount != null) 'amount': amount,
        if (dueDate != null) 'due_date': dueDate,
        if (description != null) 'description': description,
        if (applyToAllClasses != null)
          'apply_to_all_classes': applyToAllClasses,
      },
    );
  }

  Future<void> deleteStructure(
    String structureId, {
    bool deleteLinkedEntries = false,
  }) async {
    await _dio.dio.delete<dynamic>(
      '/fees/structures/$structureId',
      queryParameters: {
        if (deleteLinkedEntries) 'delete_linked_entries': true,
      },
    );
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
    String? paymentCycle,
  }) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      '/fees/ledger/generate-student',
      data: {
        'student_id': studentId,
        'standard_id': standardId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
        if (paymentCycle != null && paymentCycle.isNotEmpty)
          'payment_cycle': paymentCycle,
      },
    );
    return resp.data ?? {};
  }

  /// New: class-wise student fee summary — one row per student
  Future<Map<String, dynamic>> listClassFeeStudents({
    required String standardId,
    String? academicYearId,
    String? section,
    String? paymentCycle,
    String? status,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/fees/ledger/class-students',
      queryParameters: {
        'standard_id': standardId,
        if (_isUuid(academicYearId)) 'academic_year_id': academicYearId,
        if (section != null && section.trim().isNotEmpty) 'section': section.trim(),
        if (paymentCycle != null && paymentCycle.trim().isNotEmpty)
          'payment_cycle': paymentCycle.trim(),
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

  Future<Map<String, dynamic>> allocatePayment({
    required String studentId,
    required double amount,
    required String paymentMode,
    String? paymentCycle,
    required String paymentDate,
    String? academicYearId,
    String? referenceNumber,
    String? transactionRef,
  }) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      '/fees/payments/allocate',
      data: {
        'student_id': studentId,
        'amount': amount,
        'payment_mode': paymentMode,
        if (paymentCycle != null && paymentCycle.trim().isNotEmpty)
          'payment_cycle': paymentCycle.trim(),
        'payment_date': paymentDate,
        if (_isUuid(academicYearId)) 'academic_year_id': academicYearId,
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
  List<Map<String, dynamic>> _sections = [];
  String? _selectedYearId;
  String? _selectedStandardId;
  String? _selectedSection;
  String? _paymentCycleFilter;
  String? _statusFilter;

  // Tab data
  List<_FeeStructure> _structures = [];
  List<_StudentFeeRow> _students = [];
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _defaulters = [];
  final Map<String, String> _studentPreferredCycle = {};

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        final stillValid = stds.any(
          (s) => s['id']?.toString() == _selectedStandardId,
        );
        if ((!stillValid || _selectedStandardId == null) && stds.isNotEmpty) {
          _selectedStandardId = stds.first['id']?.toString();
        }
        if (stds.isEmpty) {
          _selectedStandardId = null;
        }
        _sections = [];
        _selectedSection = null;
      });
      await _loadSections();
      await _onTabChanged(_tabController.index);
    } catch (_) {}
  }

  Future<void> _loadSections() async {
    if (_schoolId == null || _selectedYearId == null || _selectedStandardId == null) {
      setState(() {
        _sections = [];
        _selectedSection = null;
      });
      return;
    }
    try {
      final items = await _repo.listSections(
        schoolId: _schoolId!,
        academicYearId: _selectedYearId!,
        standardId: _selectedStandardId!,
      );
      setState(() {
        _sections = items;
        final valid = items.any((s) => s['name']?.toString() == _selectedSection);
        if (!valid) _selectedSection = null;
      });
    } catch (_) {
      setState(() {
        _sections = [];
        _selectedSection = null;
      });
    }
  }

  Future<void> _onTabChanged(int i) async {
    switch (i) {
      case 0:
        await _loadStructures();
        break;
      case 1:
        await _loadStudents();
        break;
      case 2:
        await _loadAnalytics();
        break;
      case 3:
        await _loadDefaulters();
        break;
    }
  }

  Future<void> _loadStructures({bool quiet = false}) async {
    if (_selectedStandardId == null || _selectedYearId == null) return;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await _repo.listStructures(
        _selectedStandardId!,
        academicYearId: _selectedYearId,
      );
      if (mounted) setState(() => _structures = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted && !quiet) setState(() => _loading = false);
    }
  }

  Future<void> _loadStudents({bool quiet = false}) async {
    if (_selectedStandardId == null) return;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _repo.listClassFeeStudents(
        standardId: _selectedStandardId!,
        academicYearId: _selectedYearId,
        section: _selectedSection,
        paymentCycle: _paymentCycleFilter,
        status: _statusFilter,
      );
      final rawStudents = data['items'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _students = rawStudents
              .map(
                (e) =>
                    _StudentFeeRow.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted && !quiet) setState(() => _loading = false);
    }
  }

  Future<void> _loadAnalytics({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _repo.getFeeAnalytics(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
      );
      if (mounted) setState(() => _analytics = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted && !quiet) setState(() => _loading = false);
    }
  }

  Future<void> _loadDefaulters({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _repo.getDefaulters(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
      );
      if (mounted) setState(() => _defaulters = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted && !quiet) setState(() => _loading = false);
    }
  }

  /// Reloads every filter-dependent view (not only the active tab). Fixes losing
  /// the student list after Apply while on Structures / Analytics / Defaulters.
  Future<void> _applyFeeFilters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_selectedStandardId != null && _selectedYearId != null) {
        await _loadStructures(quiet: true);
      } else {
        if (mounted) setState(() => _structures = []);
      }
      if (_selectedStandardId != null) {
        await _loadStudents(quiet: true);
      } else {
        if (mounted) setState(() => _students = []);
      }
      await _loadAnalytics(quiet: true);
      await _loadDefaulters(quiet: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return '₹${d.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  Future<void> _recordPaymentForStudent(
    _StudentFeeRow student, {
    String? preferredCycle,
  }) async {
    if (student.totalOutstanding <= 0.01) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No outstanding fees for this student.'),
        ),
      );
      return;
    }

    final amountCtrl = TextEditingController(
      text: student.totalOutstanding.toStringAsFixed(2),
    );
    final referenceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMode = 'CASH';
    String paymentCycle =
        (preferredCycle ??
                _studentPreferredCycle[student.studentId] ??
                student.paymentCycle)
            .toUpperCase();
    if (paymentCycle != 'MONTHLY' &&
        paymentCycle != 'QUARTERLY' &&
        paymentCycle != 'YEARLY') {
      paymentCycle = 'YEARLY';
    }
    bool verified = false;

    double _suggestedAmountForCycle(String cycle) {
      final outstandingInstallments = student.installments
          .where((i) => i.hasOutstanding)
          .toList()
        ..sort((a, b) {
          final ad = DateTime.tryParse(a.dueDate ?? '') ?? DateTime(2100);
          final bd = DateTime.tryParse(b.dueDate ?? '') ?? DateTime(2100);
          return ad.compareTo(bd);
        });
      final total = student.totalOutstanding;
      if (total <= 0.01) return 0;

      final hasMonthlyNames = outstandingInstallments.any(
        (i) => i.installmentName.toLowerCase().contains('month'),
      );
      final hasQuarterNames = outstandingInstallments.any(
        (i) => i.installmentName.toLowerCase().contains('quarter'),
      );

      if (cycle == 'MONTHLY') {
        if (hasMonthlyNames && outstandingInstallments.isNotEmpty) {
          return outstandingInstallments.first.outstandingAmount.clamp(0.0, total);
        }
        if (hasQuarterNames && outstandingInstallments.isNotEmpty) {
          return (outstandingInstallments.first.outstandingAmount / 3).clamp(0.0, total);
        }
        return (total / 12).clamp(0.0, total);
      }
      if (cycle == 'QUARTERLY') {
        if (hasMonthlyNames) {
          final chunk = outstandingInstallments.take(3).fold<double>(
            0.0,
            (sum, i) => sum + i.outstandingAmount,
          );
          return chunk.clamp(0.0, total);
        }
        if (hasQuarterNames && outstandingInstallments.isNotEmpty) {
          return outstandingInstallments.first.outstandingAmount.clamp(0.0, total);
        }
        return (total / 4).clamp(0.0, total);
      }
      return total;
    }

    List<_InstallmentRow> _nextInstallmentsForCycle(String cycle) {
      final outstandingInstallments = student.installments
          .where((i) => i.hasOutstanding)
          .toList()
        ..sort((a, b) {
          final ad = DateTime.tryParse(a.dueDate ?? '') ?? DateTime(2100);
          final bd = DateTime.tryParse(b.dueDate ?? '') ?? DateTime(2100);
          return ad.compareTo(bd);
        });
      if (outstandingInstallments.isEmpty) return const [];
      if (cycle == 'MONTHLY') return [outstandingInstallments.first];
      if (cycle == 'QUARTERLY') {
        final hasMonthlyNames = outstandingInstallments.any(
          (i) => i.installmentName.toLowerCase().contains('month'),
        );
        return hasMonthlyNames
            ? outstandingInstallments.take(3).toList()
            : [outstandingInstallments.first];
      }
      return outstandingInstallments;
    }

    amountCtrl.text = _suggestedAmountForCycle(paymentCycle).toStringAsFixed(2);

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                'Collect Payment • ${student.studentName ?? student.admissionNumber ?? 'Student'}',
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'This payment will be auto-distributed across overdue and pending fee heads for this student.',
                          style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentCycle,
                        decoration: const InputDecoration(
                          labelText: 'Payment Cycle',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'MONTHLY',
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'QUARTERLY',
                            child: Text('Quarterly'),
                          ),
                          DropdownMenuItem(
                            value: 'YEARLY',
                            child: Text('Yearly'),
                          ),
                        ],
                        onChanged: (v) {
                          final next = v ?? 'YEARLY';
                          setDialogState(() {
                            paymentCycle = next;
                            amountCtrl.text = _suggestedAmountForCycle(next)
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
                          helperText: 'Student outstanding: auto-calculated and split',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (_) {
                          final targets = _nextInstallmentsForCycle(paymentCycle);
                          final title = paymentCycle == 'MONTHLY'
                              ? 'Next monthly installment target'
                              : paymentCycle == 'QUARTERLY'
                              ? 'Next quarterly target installment(s)'
                              : 'Yearly target (all outstanding installments)';
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange.shade900,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...targets.take(4).map((inst) {
                                  final due = inst.dueDate ?? '-';
                                  final label = inst.installmentName.trim().isEmpty
                                      ? inst.feeHead
                                      : '${inst.feeHead} • ${inst.installmentName}';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      '• $label  |  Due: $due  |  Pending: ${_fmt(inst.outstandingAmount)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  );
                                }),
                                if (targets.length > 4)
                                  Text(
                                    '...and ${targets.length - 4} more installment(s)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
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
                            value: 'CARD',
                            child: Text('Card'),
                          ),
                          DropdownMenuItem(
                            value: 'BANK_TRANSFER',
                            child: Text('Bank Transfer'),
                          ),
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
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: verified,
                        onChanged: (v) =>
                            setDialogState(() => verified = v ?? false),
                        title: const Text(
                          'Verified by admin',
                          style: TextStyle(fontSize: 13),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
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
                  onPressed: () {
                    if (!verified) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Please verify before saving payment.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
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
    if (amount > student.totalOutstanding + 0.01) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount cannot exceed outstanding ${_fmt(student.totalOutstanding)}.',
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
      final result = await _repo.allocatePayment(
        studentId: student.studentId,
        amount: amount,
        paymentMode: paymentMode,
        paymentCycle: paymentCycle,
        paymentDate: paymentDate,
        academicYearId: _selectedYearId,
        referenceNumber: referenceCtrl.text.trim().isEmpty
            ? null
            : referenceCtrl.text.trim(),
        transactionRef: notesCtrl.text.trim().isEmpty
            ? null
            : notesCtrl.text.trim(),
      );
      _studentPreferredCycle[student.studentId] = paymentCycle;
      await _loadStudents();
      await _loadAnalytics();
      await _loadDefaulters();
      if (!mounted) return;
      final applied = (result['total_applied'] as num?)?.toDouble() ?? 0;
      final unapplied = (result['total_unapplied'] as num?)?.toDouble() ?? 0;
      final allocations = (result['allocations'] as List?)?.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment collected. Applied ${_fmt(applied)} across $allocations entries${unapplied > 0 ? ', Unapplied: ${_fmt(unapplied)}' : ''}.',
          ),
        ),
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

  Future<void> _assignLedgerForStudent(
    _StudentFeeRow student, {
    bool continueToPayment = false,
  }) async {
    if (_selectedStandardId == null) return;
    String paymentCycle = 'YEARLY';
    final shouldAssign = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Assign Fee Entry • ${student.studentName ?? student.admissionNumber ?? 'Student'}',
          ),
          content: SizedBox(
            width: 360,
            child: DropdownButtonFormField<String>(
              initialValue: paymentCycle,
              decoration: const InputDecoration(
                labelText: 'Payment Cycle',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
                DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
              ],
              onChanged: (v) =>
                  setDialogState(() => paymentCycle = v ?? 'YEARLY'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (shouldAssign != true) return;

    _StudentFeeRow? updatedStudent;
    try {
      setState(() => _loading = true);
      await _repo.generateStudentLedger(
        studentId: student.studentId,
        standardId: _selectedStandardId!,
        academicYearId: _selectedYearId,
        paymentCycle: paymentCycle,
      );
      await _loadStudents();
      await _loadAnalytics();
      await _loadDefaulters();
      updatedStudent = _students.where((s) => s.studentId == student.studentId).fold<
        _StudentFeeRow?
      >(null, (prev, item) => prev ?? item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ledger assigned for ${student.studentName ?? student.admissionNumber ?? 'student'}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to assign ledger: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted || !continueToPayment) return;
    if (updatedStudent == null) return;
    if (updatedStudent.installments.isEmpty) return;
    _studentPreferredCycle[student.studentId] = paymentCycle;
    await _recordPaymentForStudent(
      updatedStudent,
      preferredCycle: paymentCycle,
    );
  }

  Future<void> _showCreateStructureDialog() async {
    if (_selectedStandardId == null || _selectedYearId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select academic year and class first.'),
        ),
      );
      return;
    }

    Map<String, dynamic> newDraft() {
      return {
        'fee_category': 'TUITION',
        'custom_fee_head_ctrl': TextEditingController(),
        'amount_ctrl': TextEditingController(),
        'desc_ctrl': TextEditingController(),
      };
    }

    final drafts = <Map<String, dynamic>>[newDraft()];
    final sharedDueDate = <DateTime>[DateTime.now()];

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Add Fee Structure'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'The same due date is applied to every fee head in this save. '
                      'Adjust amounts and categories per head below.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: const Text('Due date'),
                        subtitle: Text(
                          '${sharedDueDate[0].year}-${sharedDueDate[0].month.toString().padLeft(2, '0')}-${sharedDueDate[0].day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDate: sharedDueDate[0],
                            );
                            if (picked != null) {
                              setDialogState(() => sharedDueDate[0] = picked);
                            }
                          },
                          child: const Text('Change'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(drafts.length, (index) {
                      final draft = drafts[index];
                      final headCtrl =
                          draft['custom_fee_head_ctrl'] as TextEditingController;
                      final amountCtrl =
                          draft['amount_ctrl'] as TextEditingController;
                      final descCtrl =
                          draft['desc_ctrl'] as TextEditingController;
                      final feeCategory = draft['fee_category'] as String;
                      return Container(
                        margin: EdgeInsets.only(
                          bottom: index == drafts.length - 1 ? 0 : 12,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Fee Head ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (drafts.length > 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      (draft['custom_fee_head_ctrl']
                                              as TextEditingController)
                                          .dispose();
                                      (draft['amount_ctrl']
                                              as TextEditingController)
                                          .dispose();
                                      (draft['desc_ctrl']
                                              as TextEditingController)
                                          .dispose();
                                      setDialogState(() {
                                        drafts.removeAt(index);
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: feeCategory,
                              decoration: const InputDecoration(
                                labelText: 'Fee Category',
                                border: OutlineInputBorder(),
                              ),
                              items: _FeeRepository.feeCategories
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setDialogState(() {
                                draft['fee_category'] = v ?? 'TUITION';
                              }),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: headCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Custom Fee Head (required for Misc.)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (_) {
                                final parsed =
                                    double.tryParse(amountCtrl.text.trim()) ?? 0;
                                final monthly = parsed / 12;
                                final quarterly = parsed / 4;
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    'Auto split preview -> Monthly: ${_fmt(monthly)}, Quarterly: ${_fmt(quarterly)}, Yearly: ${_fmt(parsed)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: descCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Description (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => setDialogState(() {
                          drafts.add(newDraft());
                        }),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add another fee head'),
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
          ),
        );
      },
    );

    if (shouldSubmit != true) {
      for (final draft in drafts) {
        (draft['custom_fee_head_ctrl'] as TextEditingController).dispose();
        (draft['amount_ctrl'] as TextEditingController).dispose();
        (draft['desc_ctrl'] as TextEditingController).dispose();
      }
      return;
    }

    final dueStr =
        '${sharedDueDate[0].year}-${sharedDueDate[0].month.toString().padLeft(2, '0')}-${sharedDueDate[0].day.toString().padLeft(2, '0')}';

    final structures = <Map<String, dynamic>>[];
    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      final feeCategory = (draft['fee_category'] as String).trim();
      final head = (draft['custom_fee_head_ctrl'] as TextEditingController)
          .text
          .trim();
      final amountText =
          (draft['amount_ctrl'] as TextEditingController).text.trim();
      final amount = double.tryParse(amountText);
      final desc =
          (draft['desc_ctrl'] as TextEditingController).text.trim();

      if (amount == null || amount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter valid amount for fee head ${i + 1}.')),
        );
        return;
      }
      if (feeCategory == 'MISCELLANEOUS' && head.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Custom fee head is required for MISCELLANEOUS (row ${i + 1}).',
            ),
          ),
        );
        return;
      }

      structures.add({
        'standard_id': _selectedStandardId!,
        'academic_year_id': _selectedYearId!,
        'fee_category': feeCategory,
        'amount': amount,
        'due_date': dueStr,
        if (head.isNotEmpty) 'custom_fee_head': head,
        if (desc.isNotEmpty) 'description': desc,
      });
    }

    try {
      setState(() => _loading = true);
      await _repo.createStructuresBatch(
        structures: structures,
      );
      await _loadStructures();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            structures.length == 1
                ? 'Fee structure created.'
                : '${structures.length} fee structures created.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create structure: $e')));
    } finally {
      for (final draft in drafts) {
        (draft['custom_fee_head_ctrl'] as TextEditingController).dispose();
        (draft['amount_ctrl'] as TextEditingController).dispose();
        (draft['desc_ctrl'] as TextEditingController).dispose();
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editStructure(_FeeStructure structure) async {
    final amountCtrl = TextEditingController(
      text: structure.amount.toStringAsFixed(2),
    );
    final descCtrl = TextEditingController(text: structure.description ?? '');
    DateTime dueDate =
        DateTime.tryParse(structure.dueDate) ?? DateTime.now();
    bool applyToAll = false;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('Edit ${structure.displayLabel}'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Due Date'),
                      subtitle: Text(
                        '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: dueDate,
                          );
                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
                          }
                        },
                        child: const Text('Select'),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: applyToAll,
                      onChanged: (v) =>
                          setDialogState(() => applyToAll = v ?? false),
                      title: const Text('Apply to all classes (same fee head)'),
                      controlAffinity: ListTileControlAffinity.leading,
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
                child: const Text('Update'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldSubmit != true) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }

    try {
      setState(() => _loading = true);
      await _repo.updateStructure(
        structureId: structure.id,
        amount: amount,
        description: descCtrl.text.trim(),
        dueDate:
            '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
        applyToAllClasses: applyToAll,
      );
      await _loadStructures();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee structure updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update structure: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteStructure(_FeeStructure structure) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Structure'),
        content: Text('Delete "${structure.displayLabel}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      setState(() => _loading = true);
      await _repo.deleteStructure(structure.id);
      await _loadStructures();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee structure deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final isLinked = msg.contains('delete_linked_entries=true') ||
          msg.contains('linked with') ||
          msg.contains('422');
      if (isLinked) {
        final confirmLinked = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Linked Entries Found'),
            content: const Text(
              'This fee structure has linked ledger/payment entries. Delete all linked entries too?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes, Continue'),
              ),
            ],
          ),
        );
        if (confirmLinked == true) {
          final finalConfirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Final Confirmation'),
              content: const Text(
                'This will permanently delete the fee structure and all linked ledger/payment entries. Are you absolutely sure?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('No'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete Everything'),
                ),
              ],
            ),
          );
          if (finalConfirm == true) {
            try {
              await _repo.deleteStructure(
                structure.id,
                deleteLinkedEntries: true,
              );
              await _loadStructures();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Fee structure and linked entries deleted.',
                  ),
                ),
              );
            } catch (inner) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unable to delete linked entries: $inner')),
              );
            }
          }
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to delete structure: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateClassLedger() async {
    if (_selectedStandardId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class first.')),
      );
      return;
    }
    try {
      setState(() => _loading = true);
      final result = await _repo.generateLedger(
        _selectedStandardId!,
        academicYearId: _selectedYearId,
      );
      await _loadStudents();
      await _loadAnalytics();
      await _loadDefaulters();
      if (!mounted) return;
      final created = (result['created'] as num?)?.toInt() ?? 0;
      final skipped = (result['skipped'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Class ledger generated. Created: $created, Skipped: $skipped.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to generate class ledger: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
                Tab(text: 'Structures'),
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
                        _buildStructuresTab(),
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
                _structures = [];
                _students = [];
                _analytics = {};
                _defaulters = [];
                _sections = [];
                _selectedSection = null;
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
            items: _standards
                .map(
                  (s) => DropdownMenuItem<String?>(
                    value: s['id']?.toString(),
                    child: Text(s['name']?.toString() ?? ''),
                  ),
                )
                .toList(),
            onChanged: (v) async {
              setState(() {
                _selectedStandardId = v;
                _structures = [];
                _students = [];
                _selectedSection = null;
              });
              await _loadSections();
              if (v != null && mounted && _selectedYearId != null) {
                await _loadStructures(quiet: true);
              }
              if (v != null && mounted) {
                await _loadStudents();
              }
            },
          ),
        ),
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(
              labelText: 'Section',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _selectedSection,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All'),
              ),
              ..._sections.map(
                (s) => DropdownMenuItem<String?>(
                  value: s['name']?.toString(),
                  child: Text(s['name']?.toString() ?? ''),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() => _selectedSection = v);
              if (_selectedStandardId != null) {
                _loadStudents();
              }
            },
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(
              labelText: 'Cycle',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _paymentCycleFilter,
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('All')),
              DropdownMenuItem<String?>(
                value: 'MONTHLY',
                child: Text('Monthly'),
              ),
              DropdownMenuItem<String?>(
                value: 'QUARTERLY',
                child: Text('Quarterly'),
              ),
              DropdownMenuItem<String?>(
                value: 'YEARLY',
                child: Text('Yearly'),
              ),
              DropdownMenuItem<String?>(
                value: 'CUSTOM',
                child: Text('Custom'),
              ),
              DropdownMenuItem<String?>(
                value: 'UNASSIGNED',
                child: Text('Unassigned'),
              ),
            ],
            onChanged: (v) {
              setState(() => _paymentCycleFilter = v);
              if (_selectedStandardId != null) {
                _loadStudents();
              }
            },
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
            onChanged: (v) {
              setState(() => _statusFilter = v);
              if (_selectedStandardId != null) {
                _loadStudents();
              }
            },
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Apply'),
          onPressed: _applyFeeFilters,
        ),
      ],
    );
  }

  Widget _buildStructuresTab() {
    if (_selectedStandardId == null) {
      return const Center(
        child: Text('Please select a class to manage fee structures.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Fee Structure'),
              onPressed: _showCreateStructureDialog,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              onPressed: _loadStructures,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Generate Class Ledger'),
              onPressed: _generateClassLedger,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_structures.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No fee structures found for selected class/year.'),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Fee Head')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Class')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Due Date')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _structures.map((s) {
                  return DataRow(
                    cells: [
                      DataCell(Text(s.displayLabel)),
                      DataCell(Text(s.feeCategory)),
                      DataCell(Text(s.standardName ?? '-')),
                      DataCell(Text(_fmt(s.amount))),
                      DataCell(Text(s.dueDate)),
                      DataCell(Text(s.description?.trim().isNotEmpty == true ? s.description! : '-')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _editStructure(s),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: Colors.blue.shade700,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _deleteStructure(s),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade700,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ── Tab 0: Students ─────────────────────────────────────────────────────────

  Widget _buildStudentsTab() {
    if (_students.isEmpty) {
      final noClass = _selectedStandardId == null;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              noClass
                  ? 'Select a class (and year) first, then use Apply or Load Students.'
                  : 'No rows yet, or no students match Cycle / Status. '
                      'Class and filters are kept—click Load Students or Apply to refresh.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Load Students'),
              onPressed: noClass ? null : _loadStudents,
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
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('Adm. No.')),
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('Cycle')),
          DataColumn(label: Text('Parent')),
          DataColumn(label: Text('Parent Phone')),
          DataColumn(label: Text('Student Phone')),
          DataColumn(label: Text('Billed')),
          DataColumn(label: Text('Paid')),
          DataColumn(label: Text('Outstanding')),
          DataColumn(label: Text('Status')),
        ],
        rows: _students.map((s) {
          final statusLabel = s.status.toUpperCase();
          final statusColor = statusLabel == 'OVERDUE'
              ? Colors.red
              : statusLabel == 'PAID'
              ? Colors.green
              : statusLabel == 'PARTIAL'
              ? Colors.orange
              : Colors.blueGrey;
          return DataRow(
            cells: [
              DataCell(Text(s.studentName ?? s.admissionNumber ?? '-')),
              DataCell(
                s.installments.isEmpty
                    ? OutlinedButton.icon(
                        onPressed: () => _assignLedgerForStudent(
                          s,
                          continueToPayment: true,
                        ),
                        icon: const Icon(Icons.playlist_add, size: 16),
                        label: const Text('Assign + Update'),
                      )
                    : ElevatedButton.icon(
                        onPressed: s.installments.any((i) => i.hasOutstanding)
                            ? () => _recordPaymentForStudent(
                                s,
                                preferredCycle: _studentPreferredCycle[s.studentId],
                              )
                            : null,
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: const Text('Update'),
                      ),
              ),
              DataCell(Text(s.admissionNumber ?? '-')),
              DataCell(
                Text(
                  '${s.standardName ?? ''} ${s.section != null ? '(${s.section})' : ''}'
                      .trim(),
                ),
              ),
              DataCell(Text(s.paymentCycle)),
              DataCell(Text(s.parentName ?? '-')),
              DataCell(Text(s.parentPhone ?? '-')),
              DataCell(Text(s.studentPhone ?? '-')),
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
