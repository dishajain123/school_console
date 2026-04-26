// lib/presentation/fees/screens/fee_management_screen.dart  [Admin Console]
// Phase 5: Staff Admin (Accounts) fee management — structures, ledgers, payments.
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
  });

  final String id;
  final String feeCategory;
  final String customFeeHead;
  final double amount;
  final String dueDate;
  final String? standardName;

  factory _FeeStructure.fromJson(Map<String, dynamic> json) {
    return _FeeStructure(
      id: json['id'].toString(),
      feeCategory: json['fee_category']?.toString() ?? '',
      customFeeHead: json['custom_fee_head']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      dueDate: json['due_date']?.toString() ?? '',
      standardName: json['standard']?['name'] as String?,
    );
  }
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
  });

  final String id;
  final String? studentName;
  final String? admissionNumber;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String status;
  final String dueDate;

  factory _FeeLedger.fromJson(Map<String, dynamic> json) {
    final total = (json['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (json['paid_amount'] as num?)?.toDouble() ?? 0;
    return _FeeLedger(
      id: json['id'].toString(),
      studentName: json['student']?['user']?['full_name'] as String?,
      admissionNumber: json['student']?['admission_number'] as String?,
      totalAmount: total,
      paidAmount: paid,
      outstandingAmount: (json['outstanding_amount'] as num?)?.toDouble() ?? (total - paid),
      status: json['status']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
    );
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class _FeeRepository {
  _FeeRepository(this._dio);
  final DioClient _dio;

  Future<List<_FeeStructure>> listStructures(String standardId, {String? academicYearId}) async {
    final resp = await _dio.dio.get<dynamic>(
      '/fees/structures',
      queryParameters: {
        'standard_id': standardId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    final data = resp.data;
    final List<dynamic> raw = data is List ? data : (data?['items'] as List? ?? []);
    return raw.map((e) => _FeeStructure.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> createStructure({
    required String standardId,
    required String academicYearId,
    required String feeHead,
    required double amount,
    required String dueDate,
  }) async {
    await _dio.dio.post<dynamic>(
      '/fees/structures/batch',
      data: {
        'standard_id': standardId,
        'academic_year_id': academicYearId,
        'fee_heads': [{'name': feeHead, 'amount': amount}],
        'due_date': dueDate,
      },
    );
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

  Future<List<Map<String, dynamic>>> listStandards(String schoolId, {String? academicYearId}) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/standards',
      queryParameters: {
        'school_id': schoolId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    return ((resp.data?['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  List<Map<String, dynamic>> _standards = [];
  String? _selectedStandardId;
  String? _schoolId;

  List<_FeeStructure> _structures = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repo = _FeeRepository(ref.read(dioClientProvider));
    _schoolId = ref.read(authControllerProvider).valueOrNull?.schoolId;
    _loadStandards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStandards() async {
    if (_schoolId == null) return;
    setState(() => _loading = true);
    try {
      final stds = await _repo.listStandards(_schoolId!);
      setState(() => _standards = stds);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStructures(String standardId) async {
    setState(() { _selectedStandardId = standardId; _loading = true; });
    try {
      final structures = await _repo.listStructures(standardId);
      setState(() => _structures = structures);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateStructureDialog() async {
    final feeHeadCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dueDateCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Fee Structure'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: feeHeadCtrl, decoration: const InputDecoration(labelText: 'Fee Head (e.g. Tuition Fee)')),
            const SizedBox(height: 8),
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount (₹)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: dueDateCtrl, decoration: const InputDecoration(labelText: 'Due Date (YYYY-MM-DD)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _repo.createStructure(
                  standardId: _selectedStandardId!,
                  academicYearId: '', // backend resolves active year
                  feeHead: feeHeadCtrl.text.trim(),
                  amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                  dueDate: dueDateCtrl.text.trim(),
                );
                await _loadStructures(_selectedStandardId!);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee structure created')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateLedger() async {
    if (_selectedStandardId == null) return;
    setState(() => _loading = true);
    try {
      final result = await _repo.generateLedger(_selectedStandardId!);
      final created = result['created'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ledger generated: $created created, $skipped skipped')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Fee Management',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [Tab(text: 'Fee Structures'), Tab(text: 'Generate Ledger')],
                  ),
                  const SizedBox(height: 12),
                  // Class selector
                  Row(
                    children: [
                      const Text('Class: '),
                      const SizedBox(width: 8),
                      if (_standards.isNotEmpty)
                        DropdownButton<String>(
                          value: _selectedStandardId,
                          hint: const Text('Select Class'),
                          items: _standards.map((s) => DropdownMenuItem<String>(value: s['id']?.toString(), child: Text(s['name']?.toString() ?? ''))).toList(),
                          onChanged: (v) { if (v != null) _loadStructures(v); },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ── Tab 1: Fee Structures ────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (_selectedStandardId != null)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Fee Structure'),
                                    onPressed: _showCreateStructureDialog,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _structures.isEmpty
                                  ? const Center(child: Text('Select a class to view fee structures'))
                                  : SingleChildScrollView(
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Fee Head')),
                                          DataColumn(label: Text('Category')),
                                          DataColumn(label: Text('Amount')),
                                          DataColumn(label: Text('Due Date')),
                                        ],
                                        rows: _structures
                                            .map(
                                              (s) => DataRow(cells: [
                                                DataCell(Text(s.customFeeHead)),
                                                DataCell(Text(s.feeCategory)),
                                                DataCell(Text('₹${s.amount.toStringAsFixed(2)}')),
                                                DataCell(Text(s.dueDate)),
                                              ]),
                                            )
                                            .toList(),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        // ── Tab 2: Generate Ledger ───────────────────────────
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Generate fee ledger entries for all active students in the selected class.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: const Text('Generate Ledger'),
                                onPressed: _selectedStandardId != null ? _generateLedger : null,
                              ),
                              if (_selectedStandardId == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text('Select a class first', style: TextStyle(color: Colors.grey)),
                                ),
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