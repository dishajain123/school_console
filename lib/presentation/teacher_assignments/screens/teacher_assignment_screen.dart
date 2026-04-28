// lib/presentation/teacher_assignments/screens/teacher_assignment_screen.dart  [Admin Console]
// Phase 4 — Teacher Assignment Management.
// PRINCIPAL / SUPERADMIN: assign teachers to subject + class + section per academic year,
// view all assignments, update reassignments, delete assignments.
// History: each assignment is tied to an academic_year_id. Old-year assignments remain
// in the database as long as they are not explicitly deleted, forming per-year history.
//
// APIs used:
//   GET  /teacher-assignments?teacher_id={id}&academic_year_id={id}
//   GET  /teacher-assignments?standard_id={id}&section={s}&academic_year_id={id}
//   POST /teacher-assignments                — create assignment
//   PATCH /teacher-assignments/{id}          — update/reassign
//   DELETE /teacher-assignments/{id}         — remove assignment
//   GET  /masters/standards                  — list classes
//   GET  /masters/subjects                   — list subjects
//   GET  /masters/sections                   — list sections
//   GET  /academic-years                     — list years
//   GET  /role-profiles?role=TEACHER         — list teachers

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _Assignment {
  const _Assignment({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.employeeCode,
    required this.standardId,
    required this.standardName,
    required this.section,
    required this.subjectId,
    required this.subjectName,
    required this.academicYearId,
    required this.academicYearName,
    required this.createdAt,
  });

  final String id;
  final String teacherId;
  final String? teacherName;
  final String employeeCode;
  final String standardId;
  final String standardName;
  final String section;
  final String subjectId;
  final String subjectName;
  final String academicYearId;
  final String academicYearName;
  final String createdAt;

  factory _Assignment.fromJson(Map<String, dynamic> j) => _Assignment(
    id: j['id']?.toString() ?? '',
    teacherId: j['teacher']?['id']?.toString() ?? '',
    teacherName:
        j['teacher']?['full_name'] as String? ??
        j['teacher']?['user']?['full_name'] as String? ??
        j['teacher_name'] as String?,
    employeeCode: j['teacher']?['employee_code']?.toString() ?? '',
    standardId: j['standard']?['id']?.toString() ?? '',
    standardName: j['standard']?['name']?.toString() ?? '',
    section: j['section']?.toString() ?? '',
    subjectId: j['subject']?['id']?.toString() ?? '',
    subjectName: j['subject']?['name']?.toString() ?? '',
    academicYearId: j['academic_year']?['id']?.toString() ?? '',
    academicYearName: j['academic_year']?['name']?.toString() ?? '',
    createdAt: j['created_at']?.toString() ?? '',
  );
}

class _Teacher {
  const _Teacher({
    required this.id,
    required this.name,
    required this.employeeCode,
  });
  final String id;
  final String name;
  final String employeeCode;
}

class _DropdownItem {
  const _DropdownItem({required this.id, required this.name});
  final String id;
  final String name;
}

// ── Repository ────────────────────────────────────────────────────────────────

class _TeacherAssignmentRepository {
  _TeacherAssignmentRepository(this._dio);
  final DioClient _dio;

  Future<T> _withNetworkGuard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      final isNetwork = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.response == null;
      if (!isNetwork) rethrow;

      try {
        await _dio.dio.get<Map<String, dynamic>>('/health');
      } catch (_) {
        throw Exception(
          'Cannot reach backend server. Please ensure backend is running at ${_dio.dio.options.baseUrl}.',
        );
      }
      throw Exception(
        'Network interrupted while loading teacher assignments. Please retry.',
      );
    }
  }

  Future<List<_Assignment>> listByTeacher(
    String teacherId,
    String? yearId,
  ) async {
    final resp = await _withNetworkGuard(
      () => _dio.dio.get<Map<String, dynamic>>(
        '/teacher-assignments',
        queryParameters: {
          'teacher_id': teacherId,
          if (yearId != null) 'academic_year_id': yearId,
        },
      ),
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => _Assignment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<_Assignment>> listByClass(
    String standardId,
    String section,
    String? yearId,
  ) async {
    final resp = await _withNetworkGuard(
      () => _dio.dio.get<Map<String, dynamic>>(
        '/teacher-assignments',
        queryParameters: {
          'standard_id': standardId,
          'section': section,
          if (yearId != null) 'academic_year_id': yearId,
        },
      ),
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => _Assignment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> create({
    required String teacherId,
    required String standardId,
    required String section,
    required String subjectId,
    required String academicYearId,
  }) async {
    await _dio.dio.post<dynamic>(
      '/teacher-assignments',
      data: {
        'teacher_id': teacherId,
        'standard_id': standardId,
        'section': section,
        'subject_id': subjectId,
        'academic_year_id': academicYearId,
      },
    );
  }

  Future<void> update({
    required String assignmentId,
    required String standardId,
    required String section,
    required String subjectId,
    required String academicYearId,
  }) async {
    await _dio.dio.patch<dynamic>(
      '/teacher-assignments/$assignmentId',
      data: {
        'standard_id': standardId,
        'section': section,
        'subject_id': subjectId,
        'academic_year_id': academicYearId,
      },
    );
  }

  Future<void> delete(String assignmentId) async {
    await _dio.dio.delete<dynamic>('/teacher-assignments/$assignmentId');
  }

  Future<List<Map<String, dynamic>>> listYears() async {
    final r = await _dio.dio.get<Map<String, dynamic>>('/academic-years');
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createYear({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final r = await _dio.dio.post<Map<String, dynamic>>(
      '/academic-years',
      data: {
        'name': name.trim(),
        'start_date': _fmtDate(startDate),
        'end_date': _fmtDate(endDate),
      },
    );
    return Map<String, dynamic>.from(r.data ?? {});
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<List<_Teacher>> listTeachers() async {
    final r = await _withNetworkGuard(
      () => _dio.dio.get<Map<String, dynamic>>(
        '/role-profiles',
        queryParameters: {'role': 'TEACHER', 'page_size': 100},
      ),
    );
    final items = (r.data?['items'] as List?) ?? [];
    return items.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _Teacher(
        id: m['teacher_id']?.toString() ?? m['user_id']?.toString() ?? '',
        name: m['full_name']?.toString() ?? '',
        employeeCode: m['employee_id']?.toString() ?? '',
      );
    }).where((t) => t.id.trim().isNotEmpty).toList();
  }

  Future<List<_DropdownItem>> listStandards(String yearId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/standards',
      queryParameters: {'academic_year_id': yearId},
    );
    return ((r.data?['items'] as List?) ?? []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _DropdownItem(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
      );
    }).toList();
  }

  Future<List<_DropdownItem>> listSections(
    String standardId,
    String yearId,
  ) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/sections',
      queryParameters: {'standard_id': standardId, 'academic_year_id': yearId},
    );
    return ((r.data?['items'] as List?) ?? []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _DropdownItem(
        id: m['name']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
      );
    }).toList();
  }

  Future<List<_DropdownItem>> listSubjects({String? standardId}) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/subjects',
      queryParameters: {
        'page_size': 200,
        if (standardId != null) 'standard_id': standardId,
      },
    );
    return ((r.data?['items'] as List?) ?? []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _DropdownItem(
        id: m['id']?.toString() ?? '',
        name: '${m['name']} (${m['code']})',
      );
    }).toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TeacherAssignmentScreen extends ConsumerStatefulWidget {
  const TeacherAssignmentScreen({super.key});

  @override
  ConsumerState<TeacherAssignmentScreen> createState() =>
      _TeacherAssignmentScreenState();
}

class _TeacherAssignmentScreenState
    extends ConsumerState<TeacherAssignmentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _TeacherAssignmentRepository _repo;

  // Filter state
  List<Map<String, dynamic>> _years = [];
  List<_Teacher> _teachers = [];
  List<_DropdownItem> _standards = [];

  String? _selectedYearId;
  String? _selectedTeacherId;
  String? _filterStandardId;
  String? _filterSection;
  List<_DropdownItem> _filterSections = [];

  List<_Assignment> _assignments = [];
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repo = _TeacherAssignmentRepository(ref.read(dioClientProvider));
    _loadMeta();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _canManage {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    final role = user.role.toUpperCase();
    return role == 'PRINCIPAL' ||
        role == 'SUPERADMIN' ||
        user.permissions.contains('teacher_assignment:manage');
  }

  Future<void> _loadMeta() async {
    setState(() => _loading = true);
    try {
      final years = await _repo.listYears();
      final teachers = await _repo.listTeachers();
      final active = years.firstWhere(
        (y) => y['is_active'] == true,
        orElse: () => years.isNotEmpty ? years.first : {},
      );
      setState(() {
        _years = years;
        _teachers = teachers;
        _selectedYearId = active.isNotEmpty ? active['id']?.toString() : null;
      });
      if (_selectedYearId != null) {
        final stds = await _repo.listStandards(_selectedYearId!);
        setState(() => _standards = stds);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddYearDialog() async {
    final nameCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Academic Year'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Year Name (e.g. 2026-2027)',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setLocal(() => startDate = picked);
                          }
                        },
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
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setLocal(() => endDate = picked);
                          }
                        },
                        child: Text(
                          endDate == null
                              ? 'End Date'
                              : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    startDate == null ||
                    endDate == null) {
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  final created = await _repo.createYear(
                    name: nameCtrl.text.trim(),
                    startDate: startDate!,
                    endDate: endDate!,
                  );
                  final years = await _repo.listYears();
                  final newYearId = created['id']?.toString();
                  setState(() {
                    _years = years;
                    _selectedYearId = newYearId ?? _selectedYearId;
                    _assignments = [];
                  });
                  if (_selectedYearId != null) {
                    final stds = await _repo.listStandards(_selectedYearId!);
                    setState(() => _standards = stds);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Academic year added.')),
                    );
                  }
                } catch (e) {
                  setState(() => _error = 'Unable to add year: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadByTeacher() async {
    if (_selectedTeacherId == null) {
      setState(() => _error = 'Select a teacher first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listByTeacher(
        _selectedTeacherId!,
        _selectedYearId,
      );
      setState(() => _assignments = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadByClass() async {
    if (_filterStandardId == null || _filterSection == null) {
      setState(
        () => _error = 'Select both a class and section to filter by class.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listByClass(
        _filterStandardId!,
        _filterSection!,
        _selectedYearId,
      );
      setState(() => _assignments = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteAssignment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: const Text(
          'Remove this teacher-class-subject assignment? This only affects the selected academic year.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.delete(id);
      setState(() {
        _assignments.removeWhere((a) => a.id == id);
        _success = 'Assignment removed.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _showCreateDialog() async {
    if (!_canManage) return;
    if (_selectedYearId == null) {
      setState(() => _error = 'Select an academic year first.');
      return;
    }

    String? selTeacherId = _selectedTeacherId;
    String? selStandardId;
    String? selSection;
    String? selSubjectId;
    List<_DropdownItem> sectionOptions = [];
    List<_DropdownItem> subjectOptions = [];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Assign Teacher to Class-Subject'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Teacher
                  DropdownButtonFormField<String>(
                    value: selTeacherId,
                    decoration: const InputDecoration(
                      labelText: 'Teacher *',
                      border: OutlineInputBorder(),
                    ),
                    items: _teachers
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t.id,
                            child: Text('${t.name} (${t.employeeCode})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlgState(() => selTeacherId = v),
                  ),
                  const SizedBox(height: 12),
                  // Class
                  DropdownButtonFormField<String>(
                    value: selStandardId,
                    decoration: const InputDecoration(
                      labelText: 'Class *',
                      border: OutlineInputBorder(),
                    ),
                    items: _standards
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      setDlgState(() {
                        selStandardId = v;
                        selSection = null;
                        sectionOptions = [];
                      });
                      if (v != null) {
                        final secs = await _repo.listSections(
                          v,
                          _selectedYearId!,
                        );
                        final subs = await _repo.listSubjects(standardId: v);
                        setDlgState(() {
                          sectionOptions = secs;
                          subjectOptions = subs;
                          selSection = null;
                          selSubjectId = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Section
                  DropdownButtonFormField<String>(
                    value: selSection,
                    decoration: const InputDecoration(
                      labelText: 'Section *',
                      border: OutlineInputBorder(),
                    ),
                    items: sectionOptions
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: sectionOptions.isEmpty
                        ? null
                        : (v) => setDlgState(() => selSection = v),
                  ),
                  const SizedBox(height: 12),
                  // Subject
                  DropdownButtonFormField<String>(
                    value: selSubjectId,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      border: OutlineInputBorder(),
                    ),
                    items: subjectOptions
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: subjectOptions.isEmpty
                        ? null
                        : (v) => setDlgState(() => selSubjectId = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selTeacherId == null ||
                    selStandardId == null ||
                    selSection == null ||
                    selSubjectId == null) {
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await _repo.create(
                    teacherId: selTeacherId!,
                    standardId: selStandardId!,
                    section: selSection!,
                    subjectId: selSubjectId!,
                    academicYearId: _selectedYearId!,
                  );
                  setState(() => _success = 'Assignment created.');
                  // Reload based on current view
                  if (_selectedTeacherId != null) {
                    await _loadByTeacher();
                  }
                } catch (e) {
                  setState(() => _error = e.toString());
                }
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(_Assignment assignment) async {
    if (!_canManage) return;
    if (_selectedYearId == null) return;

    String selStandardId = assignment.standardId;
    String selSection = assignment.section;
    String selSubjectId = assignment.subjectId;
    String selYearId = assignment.academicYearId;
    List<_DropdownItem> sectionOptions = [];
    List<_DropdownItem> subjects = await _repo.listSubjects(
      standardId: selStandardId,
    );

    // Pre-load sections for the current standard
    sectionOptions = await _repo.listSections(selStandardId, selYearId);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            'Edit: ${assignment.teacherName ?? assignment.employeeCode}',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year
                  DropdownButtonFormField<String>(
                    value: selYearId,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year *',
                      border: OutlineInputBorder(),
                    ),
                    items: _years
                        .map(
                          (y) => DropdownMenuItem<String>(
                            value: y['id']?.toString() ?? '',
                            child: Text(y['name']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDlgState(() => selYearId = v ?? selYearId),
                  ),
                  const SizedBox(height: 12),
                  // Class
                  DropdownButtonFormField<String>(
                    value: selStandardId,
                    decoration: const InputDecoration(
                      labelText: 'Class *',
                      border: OutlineInputBorder(),
                    ),
                    items: _standards
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      setDlgState(() {
                        selStandardId = v ?? selStandardId;
                        selSection = '';
                        sectionOptions = [];
                      });
                      if (v != null) {
                        final secs = await _repo.listSections(v, selYearId);
                        final subs = await _repo.listSubjects(standardId: v);
                        setDlgState(() {
                          sectionOptions = secs;
                          subjects = subs;
                          selSection = '';
                          selSubjectId = '';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Section
                  DropdownButtonFormField<String>(
                    value: sectionOptions.any((s) => s.id == selSection)
                        ? selSection
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Section *',
                      border: OutlineInputBorder(),
                    ),
                    items: sectionOptions
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: sectionOptions.isEmpty
                        ? null
                        : (v) =>
                              setDlgState(() => selSection = v ?? selSection),
                  ),
                  const SizedBox(height: 12),
                  // Subject
                  DropdownButtonFormField<String>(
                    value: selSubjectId,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      border: OutlineInputBorder(),
                    ),
                    items: subjects
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDlgState(() => selSubjectId = v ?? selSubjectId),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await _repo.update(
                    assignmentId: assignment.id,
                    standardId: selStandardId,
                    section: selSection,
                    subjectId: selSubjectId,
                    academicYearId: selYearId,
                  );
                  setState(() => _success = 'Assignment updated.');
                  if (_selectedTeacherId != null) {
                    await _loadByTeacher();
                  }
                } catch (e) {
                  setState(() => _error = e.toString());
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Teacher Assignments',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Global filters ────────────────────────────────────────────
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Academic Year
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        value: _selectedYearId,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items:
                            _years
                                .map(
                                  (y) => DropdownMenuItem<String>(
                                    value: y['id']?.toString(),
                                    child: Text(
                                      '${y['name']}${y['is_active'] == true ? ' ✓' : ''}',
                                    ),
                                  ),
                                )
                                .toList()
                              ..insert(
                                0,
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Years'),
                                ),
                              ),
                        onChanged: (v) async {
                          setState(() {
                            _selectedYearId = v;
                            _standards = [];
                            _assignments = [];
                            _filterStandardId = null;
                            _filterSection = null;
                            _filterSections = [];
                          });
                          if (v != null) {
                            final stds = await _repo.listStandards(v);
                            setState(() => _standards = stds);
                          }
                        },
                      ),
                    ),
                    if (_canManage)
                      OutlinedButton.icon(
                        onPressed: _showAddYearDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Year'),
                      ),
                    if (_canManage)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Assign Teacher'),
                        onPressed: _showCreateDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Status messages ───────────────────────────────────────────
            if (_error != null)
              _Banner(
                message: _error!,
                isError: true,
                onDismiss: () => setState(() => _error = null),
              ),
            if (_success != null)
              _Banner(
                message: _success!,
                isError: false,
                onDismiss: () => setState(() => _success = null),
              ),

            // ── Search tabs ───────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.person_search_outlined),
                  text: 'By Teacher',
                ),
                Tab(icon: Icon(Icons.class_outlined), text: 'By Class'),
              ],
            ),
            const SizedBox(height: 10),

            // Tab filters
            _loading
                ? const LinearProgressIndicator()
                : _tabController.index == 0
                ? _buildTeacherFilter()
                : _buildClassFilter(),

            const SizedBox(height: 12),

            // ── Assignments table ─────────────────────────────────────────
            Expanded(
              child: _assignments.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_ind_outlined,
                            size: 56,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Use the filters above and click Search to view assignments.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade100,
                        ),
                        columns: [
                          const DataColumn(label: Text('Teacher')),
                          const DataColumn(label: Text('Emp. Code')),
                          const DataColumn(label: Text('Class')),
                          const DataColumn(label: Text('Section')),
                          const DataColumn(label: Text('Subject')),
                          const DataColumn(label: Text('Year')),
                          if (_canManage)
                            const DataColumn(label: Text('Actions')),
                        ],
                        rows: _assignments.map((a) {
                          return DataRow(
                            cells: [
                              DataCell(Text(a.teacherName ?? '-')),
                              DataCell(Text(a.employeeCode)),
                              DataCell(Text(a.standardName)),
                              DataCell(Text(a.section)),
                              DataCell(Text(a.subjectName)),
                              DataCell(Text(a.academicYearName)),
                              if (_canManage)
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Edit',
                                        onPressed: () => _showEditDialog(a),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Remove',
                                        onPressed: () =>
                                            _deleteAssignment(a.id),
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
        ),
      ),
    );
  }

  Widget _buildTeacherFilter() {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: DropdownButtonFormField<String>(
            value: _selectedTeacherId,
            decoration: const InputDecoration(
              labelText: 'Select Teacher',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: _teachers
                .map(
                  (t) => DropdownMenuItem<String>(
                    value: t.id,
                    child: Text('${t.name} (${t.employeeCode})'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedTeacherId = v),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.search, size: 16),
          label: const Text('Search'),
          onPressed: _loadByTeacher,
        ),
      ],
    );
  }

  Widget _buildClassFilter() {
    return Row(
      children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            value: _filterStandardId,
            decoration: const InputDecoration(
              labelText: 'Class',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: _standards
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(s.name),
                  ),
                )
                .toList(),
            onChanged: (v) async {
              setState(() {
                _filterStandardId = v;
                _filterSection = null;
                _filterSections = [];
              });
              if (v != null && _selectedYearId != null) {
                final sections = await _repo.listSections(v, _selectedYearId!);
                if (!mounted) return;
                setState(() => _filterSections = sections);
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            value: _filterSection,
            decoration: const InputDecoration(
              labelText: 'Section',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: _filterSections
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(s.name),
                  ),
                )
                .toList(),
            onChanged: _filterSections.isEmpty
                ? null
                : (v) => setState(() => _filterSection = v),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.search, size: 16),
          label: const Text('Search'),
          onPressed: _loadByClass,
        ),
      ],
    );
  }
}

// ── Shared banner widget ──────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({
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
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color.shade700,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: color.shade800),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 14, color: color.shade400),
          ),
        ],
      ),
    );
  }
}
