// lib/presentation/results/screens/exams_results_screen.dart  [Admin Console]
// Phase 10 — Exams & Results Screen.
// PRINCIPAL: list all exams, view class-wise result distribution, publish results.
// Backend: GET /results/exams, GET /results/exams/{id}/distribution,
//          PATCH /results/exams/{id}/publish — all fully implemented.
// This admin console screen was missing entirely.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _Exam {
  const _Exam({
    required this.id,
    required this.name,
    required this.standardName,
    required this.standardId,
    required this.startDate,
    required this.endDate,
    required this.isPublished,
    required this.academicYearId,
    required this.examType,
  });

  final String id;
  final String name;
  final String? standardName;
  final String? standardId;
  final String? startDate;
  final String? endDate;
  final bool isPublished;
  final String? academicYearId;
  final String? examType;

  factory _Exam.fromJson(Map<String, dynamic> json) => _Exam(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        standardName: json['standard']?['name'] as String? ??
            json['standard_name'] as String?,
        standardId: json['standard_id']?.toString(),
        startDate: json['start_date']?.toString(),
        endDate: json['end_date']?.toString(),
        isPublished: json['is_published'] == true,
        academicYearId: json['academic_year_id']?.toString(),
        examType: json['exam_type']?.toString(),
      );
}

class _ResultStudent {
  const _ResultStudent({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.section,
    required this.totalObtained,
    required this.totalMax,
    required this.overallPercentage,
    required this.subjects,
  });

  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String? section;
  final double totalObtained;
  final double totalMax;
  final double overallPercentage;
  final List<Map<String, dynamic>> subjects;

  factory _ResultStudent.fromJson(Map<String, dynamic> json) => _ResultStudent(
        studentId: json['student_id']?.toString() ?? '',
        studentName: json['student_name']?.toString() ?? '',
        admissionNumber: json['admission_number']?.toString() ?? '',
        section: json['section']?.toString(),
        totalObtained: _readDouble(json['total_obtained']),
        totalMax: _readDouble(json['total_max']),
        overallPercentage: _readDouble(json['overall_percentage']),
        subjects: _parseSubjectMaps(json['subjects']),
      );

  static double _readDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static List<Map<String, dynamic>> _parseSubjectMaps(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  Color get percentageColor {
    if (overallPercentage >= 75) return Colors.green;
    if (overallPercentage >= 50) return Colors.orange;
    return Colors.red;
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class _ResultsRepository {
  _ResultsRepository(this._dio);
  final DioClient _dio;

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

  // GET /results/exams — list all exams (principal sees all)
  Future<List<_Exam>> listExams({
    String? academicYearId,
    String? standardId,
  }) async {
    final resp = await _dio.dio.get<dynamic>(
      '/results/exams',
      queryParameters: {
        if (academicYearId != null) 'academic_year_id': academicYearId,
        if (standardId != null) 'standard_id': standardId,
      },
    );
    final raw = resp.data is List
        ? resp.data as List
        : ((resp.data as Map?)?['items'] as List? ?? []);
    return raw
        .map((e) => _Exam.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> createExamForAllClasses({
    required String name,
    required String startDate,
    required String endDate,
    String? academicYearId,
  }) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      '/results/exams/bulk',
      data: {
        'name': name,
        'apply_to_all_standards': true,
        if (academicYearId != null) 'academic_year_id': academicYearId,
        'start_date': startDate,
        'end_date': endDate,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  // GET /results/exams/{id}/distribution — class result distribution
  Future<List<_ResultStudent>> getDistribution(
    String examId, {
    String? section,
  }) async {
    final resp = await _dio.dio.get<dynamic>(
      '/results/exams/$examId/distribution',
      queryParameters: {
        if (section != null && section.trim().isNotEmpty) 'section': section,
      },
    );
    final data = resp.data;
    if (data is! Map) {
      throw FormatException('Unexpected distribution response shape');
    }
    final map = Map<String, dynamic>.from(data);
    final rawItems = map['items'];
    if (rawItems == null) return const [];
    if (rawItems is! List) {
      throw FormatException('distribution.items is not a list');
    }
    final out = <_ResultStudent>[];
    for (final e in rawItems) {
      if (e is! Map) continue;
      try {
        out.add(_ResultStudent.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  // PATCH /results/exams/{id}/publish — publish all results (principal only)
  Future<int> publishExam(String examId) async {
    final resp = await _dio.dio.patch<Map<String, dynamic>>(
      '/results/exams/$examId/publish',
    );
    return (resp.data?['updated'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteExam(String examId) async {
    await _dio.dio.delete<dynamic>('/results/exams/$examId');
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ExamsResultsScreen extends ConsumerStatefulWidget {
  const ExamsResultsScreen({super.key});

  @override
  ConsumerState<ExamsResultsScreen> createState() =>
      _ExamsResultsScreenState();
}

class _ExamsResultsScreenState extends ConsumerState<ExamsResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _ResultsRepository _repo;

  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];
  List<_Exam> _exams = [];
  List<_ResultStudent> _distribution = [];
  bool _distributionLoading = false;
  String? _distributionError;

  _Exam? _selectedExam;
  String? _selectedYearId;
  String? _selectedStandardId;

  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repo = _ResultsRepository(ref.read(dioClientProvider));
    _loadYears();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  bool get _canPublish {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    final role = user.role.toUpperCase();
    return role == 'PRINCIPAL' ||
        role == 'SUPERADMIN' ||
        user.permissions.contains('result:publish');
  }

  bool get _canCreateExam {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    final role = user.role.toUpperCase();
    return role == 'PRINCIPAL' ||
        role == 'SUPERADMIN' ||
        user.permissions.contains('result:create');
  }

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
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
        await _loadExams();
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

  Future<void> _loadExams() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exams = await _repo.listExams(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
      );
      setState(() {
        _exams = exams;
        _selectedExam = null;
        _distribution = [];
        _distributionError = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadDistribution(_Exam exam) async {
    setState(() {
      _selectedExam = exam;
      _distributionLoading = true;
      _distributionError = null;
      _error = null;
      _distribution = [];
    });
    _tabController.animateTo(1);
    try {
      final dist = await _repo.getDistribution(exam.id);
      if (!mounted) return;
      setState(() {
        _distribution = dist;
        _distributionError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _distributionError = e.toString();
        _distribution = [];
      });
    } finally {
      if (mounted) setState(() => _distributionLoading = false);
    }
  }

  Future<void> _publishExam(_Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish Results'),
        content: Text(
          'Publish all results for "${exam.name}"?\n\n'
          'Students and parents will be able to view their marks and report cards. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Publish',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final updated = await _repo.publishExam(exam.id);
      await _loadExams();
      if (mounted) {
        setState(() =>
            _success = '$updated result(s) published for "${exam.name}".');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteExam(_Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exam'),
        content: Text(
          'Delete "${exam.name}" for ${exam.standardName ?? 'selected class'}?\n\n'
          'This deletes associated entered results for this exam as well.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await _repo.deleteExam(exam.id);
      await _loadExams();
      if (mounted) {
        setState(() => _success = 'Exam "${exam.name}" deleted successfully.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateExamDialog() async {
    if (!_canCreateExam) return;
    final nameCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool submitting = false;

    Future<void> pickDate(bool isStart, StateSetter setLocal) async {
      final now = DateTime.now();
      final initial = (isStart ? startDate : endDate) ?? now;
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime(2035, 12, 31),
      );
      if (picked == null) return;
      setLocal(() {
        if (isStart) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
        }
      });
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create Exam (All Classes)'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Exam Name',
                    hintText: 'e.g. Unit Test 1 / Semester / Finals',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pickDate(true, setLocal),
                        child: Text(
                          startDate == null
                              ? 'Start Date'
                              : '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pickDate(false, setLocal),
                        child: Text(
                          endDate == null
                              ? 'End Date'
                              : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Creates this exam for all classes in the selected academic year.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      var dialogClosed = false;
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty || startDate == null || endDate == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill all fields')),
                          );
                        }
                        return;
                      }
                      if (endDate!.isBefore(startDate!)) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('End date must be on or after start date'),
                            ),
                          );
                        }
                        return;
                      }
                      setLocal(() => submitting = true);
                      try {
                        final payload = await _repo.createExamForAllClasses(
                          name: name,
                          startDate:
                              '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                          endDate:
                              '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                          academicYearId: _selectedYearId,
                        );
                        final createdCount =
                            (payload['created_count'] as num?)?.toInt() ?? 0;
                        final skippedCount =
                            (payload['skipped_count'] as num?)?.toInt() ?? 0;
                        if (mounted) {
                          dialogClosed = true;
                          Navigator.of(ctx).pop();
                          setState(() {
                            _success =
                                'Exam "$name" created for $createdCount class(es). '
                                'Skipped: $skippedCount.';
                            _error = null;
                          });
                        }
                        await _loadExams();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                        if (ctx.mounted) {
                          setLocal(() => submitting = false);
                        }
                      } finally {
                        if (!dialogClosed && ctx.mounted) {
                          setLocal(() => submitting = false);
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Exams & Results',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filters ──────────────────────────────────────────────────
            Wrap(
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
                        _selectedExam = null;
                        _distribution = [];
                        _distributionError = null;
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
                        labelText: 'Class (optional)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    value: _selectedStandardId,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('All Classes')),
                      ..._standards.map((s) => DropdownMenuItem<String?>(
                          value: s['id']?.toString(),
                          child: Text(s['name']?.toString() ?? ''))),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedStandardId = v;
                      _selectedExam = null;
                      _distribution = [];
                      _distributionError = null;
                    }),
                  ),
                ),
                ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search, size: 16),
                  label: const Text('Load Exams'),
                  onPressed: _loading ? null : _loadExams,
                ),
                if (_canCreateExam)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Create Exam (All Classes)'),
                    onPressed: _openCreateExamDialog,
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
                child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade700)),
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

            // ── Tabs ─────────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'Exam List'),
                Tab(
                    text: _selectedExam != null
                        ? 'Distribution: ${_selectedExam!.name}'
                        : 'Distribution'),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExamListTab(),
                  _buildDistributionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Exam List Tab ───────────────────────────────────────────────────────────

  Widget _buildExamListTab() {
    if (_exams.isEmpty && !_loading) {
      return const Center(
          child: Text(
              'No exams found. Select year and click Load Exams.'));
    }
    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        columns: [
          const DataColumn(label: Text('Exam Name')),
          const DataColumn(label: Text('Class')),
          const DataColumn(label: Text('Type')),
          const DataColumn(label: Text('Start')),
          const DataColumn(label: Text('End')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: _exams.map((exam) {
          final isPublished = exam.isPublished;
          return DataRow(cells: [
            DataCell(Text(exam.name,
                style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(exam.standardName ?? '-')),
            DataCell(Text(exam.examType ?? '-')),
            DataCell(Text(exam.startDate ?? '-')),
            DataCell(Text(exam.endDate ?? '-')),
            DataCell(Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isPublished
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isPublished ? 'Published' : 'Unpublished',
                style: TextStyle(
                    color: isPublished
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.bar_chart_outlined, size: 14),
                  label: const Text('View',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () => _loadDistribution(exam),
                ),
                if (_canEdit(exam))
                  TextButton.icon(
                    icon: Icon(Icons.publish_outlined,
                        size: 14,
                        color: isPublished
                            ? Colors.grey
                            : Colors.green),
                    label: Text(
                      isPublished ? 'Published' : 'Publish',
                      style: TextStyle(
                          fontSize: 12,
                          color: isPublished
                              ? Colors.grey
                              : Colors.green),
                    ),
                    onPressed: isPublished
                        ? null
                        : () => _publishExam(exam),
                  ),
                if (_canCreateExam)
                  TextButton.icon(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    onPressed: () => _deleteExam(exam),
                  ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  bool _canEdit(_Exam exam) => _canPublish;

  // ── Distribution Tab ────────────────────────────────────────────────────────

  Widget _buildDistributionTab() {
    if (_selectedExam == null) {
      return const Center(
          child: Text(
              'Select an exam from the list and click View.'));
    }
    if (_distributionLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_distributionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                'Could not load distribution',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(
                _distributionError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadDistribution(_selectedExam!),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_distribution.isEmpty) {
      return const Center(
          child: Text('No results entered for this exam yet.'));
    }

    final sorted = List<_ResultStudent>.from(_distribution)
      ..sort((a, b) =>
          b.overallPercentage.compareTo(a.overallPercentage));

    final avg = sorted.isEmpty
        ? 0.0
        : sorted
                .map((s) => s.overallPercentage)
                .reduce((a, b) => a + b) /
            sorted.length;
    final passCount = sorted.where((s) => s.overallPercentage >= 35).length;

    return Column(
      children: [
        // Summary
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 12,
            children: [
              Chip(
                  label: Text('Total: ${sorted.length}'),
                  backgroundColor: Colors.grey.shade200),
              Chip(
                  label: Text(
                      'Avg: ${avg.toStringAsFixed(1)}%'),
                  backgroundColor: avg >= 60
                      ? Colors.green.shade100
                      : Colors.orange.shade100),
              Chip(
                  label:
                      Text('Passed (≥35%): $passCount'),
                  backgroundColor: Colors.green.shade100),
              Chip(
                  label: Text(
                      'Failed: ${sorted.length - passCount}'),
                  backgroundColor: Colors.red.shade100),
            ],
          ),
        ),
        // Table
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(Colors.grey.shade100),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Adm. No.')),
                DataColumn(label: Text('Student')),
                DataColumn(label: Text('Section')),
                DataColumn(label: Text('Obtained')),
                DataColumn(label: Text('Max')),
                DataColumn(label: Text('%')),
              ],
              rows: sorted.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final s = entry.value;
                return DataRow(cells: [
                  DataCell(Text('$rank',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey))),
                  DataCell(Text(s.admissionNumber)),
                  DataCell(Text(s.studentName)),
                  DataCell(Text(s.section ?? '-')),
                  DataCell(Text(s.totalObtained.toStringAsFixed(1))),
                  DataCell(Text(s.totalMax.toStringAsFixed(1))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: s.percentageColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${s.overallPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: s.percentageColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
