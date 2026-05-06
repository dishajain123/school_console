// lib/presentation/teacher_assignments/screens/teacher_assignment_screen.dart  [Admin Console]
// Phase 4 — Teacher Assignment Management.
// PRINCIPAL / STAFF_ADMIN: assign teachers to subject + class + section per academic year,
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

import '../../../core/theme/admin_colors.dart';
import '../../../data/repositories/teacher_assignments_repository.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/teacher_assignments_repository_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_filter_card.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _Assignment {
  const _Assignment({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.employeeCode,
    required this.teacherEmail,
    required this.teacherPhone,
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
  final String teacherEmail;
  final String teacherPhone;
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
    teacherEmail: j['teacher']?['email']?.toString() ?? '',
    teacherPhone: j['teacher']?['phone']?.toString() ?? '',
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
    required this.userId,
    required this.hasProfile,
    required this.name,
    required this.employeeCode,
    required this.email,
    required this.phone,
  });
  final String id;
  final String userId;
  final bool hasProfile;
  final String name;
  final String employeeCode;
  final String email;
  final String phone;
}

class _DropdownItem {
  const _DropdownItem({required this.id, required this.name});
  final String id;
  final String name;
}

class _LeaveBalanceItem {
  const _LeaveBalanceItem({
    required this.leaveType,
    required this.totalDays,
    required this.usedDays,
    required this.remainingDays,
  });

  final String leaveType;
  final double totalDays;
  final double usedDays;
  final double remainingDays;

  factory _LeaveBalanceItem.fromJson(Map<String, dynamic> json) {
    return _LeaveBalanceItem(
      leaveType: (json['leave_type'] ?? '').toString(),
      totalDays: (json['total_days'] as num?)?.toDouble() ?? 0,
      usedDays: (json['used_days'] as num?)?.toDouble() ?? 0,
      remainingDays: (json['remaining_days'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _LeaveRequestItem {
  const _LeaveRequestItem({
    required this.id,
    required this.leaveType,
    required this.status,
    required this.fromDate,
    required this.toDate,
    this.reason,
  });

  final String id;
  final String leaveType;
  final String status;
  final String fromDate;
  final String toDate;
  final String? reason;

  factory _LeaveRequestItem.fromJson(Map<String, dynamic> json) {
    return _LeaveRequestItem(
      id: (json['id'] ?? '').toString(),
      leaveType: (json['leave_type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      fromDate: (json['from_date'] ?? '').toString(),
      toDate: (json['to_date'] ?? '').toString(),
      reason: json['reason']?.toString(),
    );
  }
}

// Maps [TeacherAssignmentsRepository] payloads to UI models.

_Teacher _teacherFromRoleProfileMap(Map<String, dynamic> m) {
  final teacherId = m['teacher_id']?.toString() ?? '';
  final userId = m['user_id']?.toString() ?? '';
  final selectionId = teacherId.isNotEmpty ? teacherId : 'user:$userId';
  final identifier =
      m['employee_id']?.toString() ?? m['identifier']?.toString() ?? '';
  return _Teacher(
    id: selectionId,
    userId: userId,
    hasProfile: teacherId.isNotEmpty,
    name: m['full_name']?.toString() ?? '',
    employeeCode: identifier,
    email: m['email']?.toString() ?? '',
    phone: m['phone']?.toString() ?? '',
  );
}

_DropdownItem _standardDropdown(Map<String, dynamic> m) => _DropdownItem(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
    );

_DropdownItem _sectionDropdown(Map<String, dynamic> m) => _DropdownItem(
      id: m['name']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
    );

_DropdownItem _subjectDropdown(Map<String, dynamic> m) => _DropdownItem(
      id: m['id']?.toString() ?? '',
      name: '${m['name']} (${m['code']})',
    );

List<_Assignment> _assignmentsFromMaps(List<Map<String, dynamic>> maps) => maps
    .map(_Assignment.fromJson)
    .toList(growable: false);

Future<List<_Teacher>> _loadTeachers(TeacherAssignmentsRepository repo) async {
  final maps = await repo.listTeacherRoleProfileMaps();
  return maps
      .map(_teacherFromRoleProfileMap)
      .where((t) => t.id.trim().isNotEmpty)
      .toList(growable: false);
}

Future<List<_LeaveBalanceItem>> _leaveBalancesFromRepo(
  TeacherAssignmentsRepository repo,
  String teacherId, {
  String? academicYearId,
}) async {
  final maps =
      await repo.getTeacherLeaveBalances(teacherId, academicYearId: academicYearId);
  return maps.map(_LeaveBalanceItem.fromJson).toList(growable: false);
}

Future<List<_LeaveRequestItem>> _leaveRequestsFromRepo(
  TeacherAssignmentsRepository repo,
  String teacherId, {
  String? academicYearId,
}) async {
  final maps =
      await repo.listTeacherLeaves(teacherId, academicYearId: academicYearId);
  return maps.map(_LeaveRequestItem.fromJson).toList(growable: false);
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

  TeacherAssignmentsRepository get _repo =>
      ref.read(teacherAssignmentsRepositoryProvider);

  // Filter state
  List<Map<String, dynamic>> _years = [];
  List<_Teacher> _teachers = [];
  List<_DropdownItem> _standards = [];
  Map<String, bool> _teacherAssignedBySelectionId = {};

  String? _selectedYearId;
  String? _selectedTeacherId;
  String _teacherStatusFilter = 'PENDING';
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
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
    _loadMeta();
  }

  void _resetTeacherScopeFilters() {
    setState(() {
      _teacherStatusFilter = 'ALL';
      _selectedTeacherId = null;
    });
  }

  void _resetClassScopeFilters() {
    setState(() {
      _filterStandardId = null;
      _filterSection = null;
      _filterSections = [];
    });
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
        role == 'STAFF_ADMIN' ||
        user.permissions.contains('teacher_assignment:manage');
  }

  List<_Teacher> get _visibleTeachers {
    if (_teacherStatusFilter == 'ALL') return _teachers;
    return _teachers.where((t) {
      final assigned = _teacherAssignedBySelectionId[t.id] == true;
      return _teacherStatusFilter == 'ASSIGNED' ? assigned : !assigned;
    }).toList();
  }

  Future<void> _refreshTeacherAssignmentStatus() async {
    final statusByUser = await _repo.teacherEnrollmentStatusByUser(
      academicYearId: _selectedYearId,
    );
    final map = <String, bool>{};
    for (final t in _teachers) {
      final row = statusByUser[t.userId];
      final assigned = row?['enrollment_completed'] == true;
      map[t.id] = assigned;
    }
    if (!mounted) return;
    setState(() => _teacherAssignedBySelectionId = map);
  }

  Future<void> _loadMeta() async {
    setState(() => _loading = true);
    try {
      final years = await _repo.listAcademicYears();
      final teachers = await _loadTeachers(_repo);
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
      setState(() {
        _years = years;
        _teachers = teachers;
        _selectedYearId = selected.isNotEmpty
            ? selected['id']?.toString()
            : null;
      });
      ref.read(activeAcademicYearProvider.notifier).setYear(_selectedYearId);
      if (_selectedYearId != null) {
        final maps = await _repo.listStandardMaps(_selectedYearId!);
        setState(() => _standards = maps.map(_standardDropdown).toList());
      }
      await _refreshTeacherAssignmentStatus();
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
                  final created = await _repo.createAcademicYear(
                    name: nameCtrl.text.trim(),
                    startDate: startDate!,
                    endDate: endDate!,
                  );
                  final years = await _repo.listAcademicYears();
                  final newYearId = created['id']?.toString();
                  setState(() {
                    _years = years;
                    _selectedYearId = newYearId ?? _selectedYearId;
                    _assignments = [];
                  });
                  if (_selectedYearId != null) {
                    final maps = await _repo.listStandardMaps(_selectedYearId!);
                    setState(
                      () => _standards = maps.map(_standardDropdown).toList(),
                    );
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
    if (_selectedTeacherId!.startsWith('user:')) {
      setState(
        () => _error =
            'Selected teacher profile is pending. Create teacher profile first, then search again.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = _assignmentsFromMaps(
        await _repo.listAssignmentsByTeacher(
          _selectedTeacherId!,
          _selectedYearId,
        ),
      );
      setState(() => _assignments = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadByClass() async {
    if (_filterStandardId == null) {
      setState(() => _error = 'Select class to filter assignments.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = _filterSection == null || _filterSection!.trim().isEmpty
          ? _assignmentsFromMaps(
              await _repo.listAssignmentsByStandard(
                _filterStandardId!,
                _selectedYearId,
              ),
            )
          : _assignmentsFromMaps(
              await _repo.listAssignmentsByClass(
                _filterStandardId!,
                _filterSection!,
                _selectedYearId,
              ),
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.danger,
              foregroundColor: AdminColors.textOnPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deleteAssignment(id);
      setState(() {
        _assignments.removeWhere((a) => a.id == id);
        _success = 'Assignment removed.';
      });
      await _refreshTeacherAssignmentStatus();
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
                  DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'dlg_ct_${selTeacherId}_${selStandardId}_${sectionOptions.length}_${subjectOptions.length}',
                    ),
                    initialValue: selTeacherId,
                    decoration: const InputDecoration(
                      labelText: 'Teacher *',
                      border: OutlineInputBorder(),
                    ),
                    items: _teachers
                        .map(
                          (t) => DropdownMenuItem<String?>(
                            value: t.id,
                            child: Text(
                              t.hasProfile
                                  ? '${t.name} (${t.employeeCode})'
                                  : '${t.name} (${t.employeeCode.isNotEmpty ? t.employeeCode : 'pending id'}) • Profile pending',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlgState(() => selTeacherId = v),
                  ),
                  const SizedBox(height: 12),
                  // Class
                  DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'dlg_cs_${selStandardId}_${sectionOptions.length}',
                    ),
                    initialValue: selStandardId,
                    decoration: const InputDecoration(
                      labelText: 'Class *',
                      border: OutlineInputBorder(),
                    ),
                    items: _standards
                        .map(
                          (s) => DropdownMenuItem<String?>(
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
                        final secMaps = await _repo.listSectionMaps(
                          v,
                          _selectedYearId!,
                        );
                        final subMaps =
                            await _repo.listSubjectMaps(standardId: v);
                        setDlgState(() {
                          sectionOptions = secMaps.map(_sectionDropdown).toList();
                          subjectOptions = subMaps.map(_subjectDropdown).toList();
                          selSection = null;
                          selSubjectId = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Section
                  DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'dlg_csec_${selSection}_${sectionOptions.length}',
                    ),
                    initialValue: selSection,
                    decoration: const InputDecoration(
                      labelText: 'Section *',
                      border: OutlineInputBorder(),
                    ),
                    items: sectionOptions
                        .map(
                          (s) => DropdownMenuItem<String?>(
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
                  DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'dlg_csub_${selSubjectId}_${subjectOptions.length}',
                    ),
                    initialValue: selSubjectId,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      border: OutlineInputBorder(),
                    ),
                    items: subjectOptions
                        .map(
                          (s) => DropdownMenuItem<String?>(
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
                  var finalTeacherId = selTeacherId!;
                  if (finalTeacherId.startsWith('user:')) {
                    final selectedTeacher = _teachers
                        .cast<_Teacher?>()
                        .firstWhere(
                          (t) => t?.id == finalTeacherId,
                          orElse: () => null,
                        );
                    final userId = finalTeacherId.substring(5);
                    final created = await _repo.createTeacherProfile(
                      userId: userId,
                      customEmployeeId: selectedTeacher?.employeeCode,
                    );
                    final newTeacherId = (created['teacher_id'] ?? '')
                        .toString();
                    if (newTeacherId.isEmpty) {
                      throw Exception(
                        'Failed to create teacher profile before assignment.',
                      );
                    }
                    final oldSelectionId = finalTeacherId;
                    finalTeacherId = newTeacherId;
                    selTeacherId = newTeacherId;
                    _teachers = _teachers.map((t) {
                      if (t.id != oldSelectionId) return t;
                      return _Teacher(
                        id: newTeacherId,
                        userId: t.userId,
                        hasProfile: true,
                        name: t.name,
                        employeeCode: t.employeeCode,
                        email: t.email,
                        phone: t.phone,
                      );
                    }).toList();
                  }
                  await _repo.createAssignment(
                    teacherId: finalTeacherId,
                    standardId: selStandardId!,
                    section: selSection!,
                    subjectId: selSubjectId!,
                    academicYearId: _selectedYearId!,
                  );
                  setState(() {
                    _selectedTeacherId = finalTeacherId;
                    _error = null;
                    _success = 'Assignment created.';
                  });
                  // Reload based on current view
                  if (_selectedTeacherId != null) {
                    await _loadByTeacher();
                  }
                  await _refreshTeacherAssignmentStatus();
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

  Future<void> _showReenrollTeacherDialog() async {
    if (!_canManage) return;
    if (_selectedTeacherId == null || _selectedTeacherId!.startsWith('user:')) {
      setState(() => _error = 'Select an enrolled teacher profile first.');
      return;
    }
    if (_years.length < 2) {
      setState(() => _error = 'At least two academic years are required.');
      return;
    }

    String sourceYearId = _selectedYearId ?? (_years.first['id']?.toString() ?? '');
    String targetYearId = _years
            .firstWhere(
              (y) => y['id']?.toString() != sourceYearId,
              orElse: () => _years.first,
            )['id']
            ?.toString() ??
        '';
    bool overwrite = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Re-enroll Teacher Assignments'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This copies this teacher\'s class-section-subject assignments from source year to target year. You can edit rows after copy.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('re_src_${sourceYearId}_${_years.length}'),
                  initialValue: sourceYearId.isEmpty ? null : sourceYearId,
                  decoration: const InputDecoration(
                    labelText: 'Source Academic Year',
                    border: OutlineInputBorder(),
                  ),
                  items: _years
                      .map(
                        (y) => DropdownMenuItem<String?>(
                          value: y['id']?.toString(),
                          child: Text(y['name']?.toString() ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() {
                      sourceYearId = v;
                      if (targetYearId == sourceYearId) {
                        targetYearId = _years
                                .firstWhere(
                                  (y) => y['id']?.toString() != sourceYearId,
                                  orElse: () => _years.first,
                                )['id']
                                ?.toString() ??
                            '';
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('re_tgt_${targetYearId}_$sourceYearId'),
                  initialValue: targetYearId.isEmpty ? null : targetYearId,
                  decoration: const InputDecoration(
                    labelText: 'Target Academic Year',
                    border: OutlineInputBorder(),
                  ),
                  items: _years
                      .where((y) => y['id']?.toString() != sourceYearId)
                      .map(
                        (y) => DropdownMenuItem<String?>(
                          value: y['id']?.toString(),
                          child: Text(y['name']?.toString() ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() => targetYearId = v);
                  },
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  dense: true,
                  value: overwrite,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Overwrite duplicate target assignments'),
                  onChanged: (v) => setLocal(() => overwrite = v ?? false),
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
                if (sourceYearId.isEmpty ||
                    targetYearId.isEmpty ||
                    sourceYearId == targetYearId) {
                  return;
                }
                Navigator.of(ctx).pop();
                setState(() {
                  _loading = true;
                  _error = null;
                  _success = null;
                });
                try {
                  final result = await _repo.reenrollTeacher(
                    teacherId: _selectedTeacherId!,
                    sourceYearId: sourceYearId,
                    targetYearId: targetYearId,
                    overwriteExisting: overwrite,
                  );
                  final copied = (result['copied_count'] as num?)?.toInt() ?? 0;
                  final skipped = (result['skipped_count'] as num?)?.toInt() ?? 0;
                  final errors = (result['error_count'] as num?)?.toInt() ?? 0;
                  _selectedYearId = targetYearId;
                  ref.read(activeAcademicYearProvider.notifier).setYear(targetYearId);
                  final stdMaps = await _repo.listStandardMaps(targetYearId);
                  setState(() {
                    _standards = stdMaps.map(_standardDropdown).toList();
                    _success =
                        'Teacher re-enrolled: copied $copied, skipped $skipped, errors $errors. You can edit assignments below.';
                  });
                  await _loadByTeacher();
                  await _refreshTeacherAssignmentStatus();
                } catch (e) {
                  setState(() => _error = e.toString());
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: const Text('Re-enroll'),
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
    final subMaps =
        await _repo.listSubjectMaps(standardId: selStandardId);
    List<_DropdownItem> subjects = subMaps.map(_subjectDropdown).toList();

    // Pre-load sections for the current standard
    final secMaps = await _repo.listSectionMaps(selStandardId, selYearId);
    sectionOptions = secMaps.map(_sectionDropdown).toList();

    if (!mounted) return;
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
                    key: ValueKey('ed_y_$selYearId'),
                    initialValue: selYearId,
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
                    key: ValueKey('ed_std_${selStandardId}_$selYearId'),
                    initialValue: selStandardId,
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
                        final secMaps = await _repo.listSectionMaps(v, selYearId);
                        final subMaps =
                            await _repo.listSubjectMaps(standardId: v);
                        setDlgState(() {
                          sectionOptions = secMaps.map(_sectionDropdown).toList();
                          subjects = subMaps.map(_subjectDropdown).toList();
                          selSection = '';
                          selSubjectId = '';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Section
                  DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'ed_sec_${selSection}_${sectionOptions.map((e) => e.id).join(',')}',
                    ),
                    initialValue: sectionOptions.any((s) => s.id == selSection)
                        ? selSection
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Section *',
                      border: OutlineInputBorder(),
                    ),
                    items: sectionOptions
                        .map(
                          (s) => DropdownMenuItem<String?>(
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
                    key: ValueKey('ed_sub_${selSubjectId}_${subjects.length}'),
                    initialValue: selSubjectId,
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
                  await _repo.updateAssignment(
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
                  await _refreshTeacherAssignmentStatus();
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

  String _leaveTypeLabel(String value) {
    final key = value.trim().toUpperCase();
    switch (key) {
      case 'CASUAL':
        return 'Casual';
      case 'SICK':
        return 'Sick';
      case 'EARNED':
        return 'Earned';
      default:
        return key;
    }
  }

  Future<void> _showTeacherLeaveDialog(_Teacher teacher) async {
    if (teacher.id.startsWith('user:')) {
      setState(
        () => _error =
            'Teacher profile is pending. Complete profile before managing leave allocation.',
      );
      return;
    }

    try {
      final balances = await _leaveBalancesFromRepo(
        _repo,
        teacher.id,
        academicYearId: _selectedYearId,
      );
      final leaves = await _leaveRequestsFromRepo(
        _repo,
        teacher.id,
        academicYearId: _selectedYearId,
      );

      double byType(List<_LeaveBalanceItem> items, String type) {
        for (final item in items) {
          if (item.leaveType.toUpperCase() == type) return item.totalDays;
        }
        return 0;
      }

      final casualCtrl = TextEditingController(
        text: byType(balances, 'CASUAL').toStringAsFixed(0),
      );
      final sickCtrl = TextEditingController(
        text: byType(balances, 'SICK').toStringAsFixed(0),
      );
      final earnedCtrl = TextEditingController(
        text: byType(balances, 'EARNED').toStringAsFixed(0),
      );

      var localBalances = List<_LeaveBalanceItem>.from(balances);
      var saving = false;

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlgState) {
            final pending = leaves
                .where((l) => l.status.toUpperCase() == 'PENDING')
                .length;
            final approved = leaves
                .where((l) => l.status.toUpperCase() == 'APPROVED')
                .length;
            final rejected = leaves
                .where((l) => l.status.toUpperCase() == 'REJECTED')
                .length;

            return AlertDialog(
              title: Text('Teacher Leave: ${teacher.name}'),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave request overview (Principal decisions reflected):',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Pending: $pending')),
                          Chip(label: Text('Approved: $approved')),
                          Chip(label: Text('Rejected: $rejected')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (localBalances.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: localBalances
                                .map(
                                  (b) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${_leaveTypeLabel(b.leaveType)}: '
                                      'Allocated ${b.totalDays.toStringAsFixed(0)} | '
                                      'Used ${b.usedDays.toStringAsFixed(0)} | '
                                      'Remaining ${b.remainingDays.toStringAsFixed(0)}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        )
                      else
                        const Text('No leave allocation configured yet.'),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Manage allocation (Admin Console)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: casualCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Casual Days',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: sickCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Sick Days',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: earnedCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Earned Days',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final casual = double.tryParse(
                            casualCtrl.text.trim(),
                          );
                          final sick = double.tryParse(sickCtrl.text.trim());
                          final earned = double.tryParse(
                            earnedCtrl.text.trim(),
                          );
                          if (casual == null ||
                              sick == null ||
                              earned == null ||
                              casual < 0 ||
                              sick < 0 ||
                              earned < 0) {
                            setState(() {
                              _error =
                                  'Please enter valid non-negative leave days.';
                            });
                            return;
                          }
                          setDlgState(() => saving = true);
                          try {
                            final updatedMaps =
                                await _repo.setTeacherLeaveBalances(
                              teacherId: teacher.id,
                              academicYearId: _selectedYearId,
                              casualDays: casual,
                              sickDays: sick,
                              earnedDays: earned,
                            );
                            setDlgState(() {
                              localBalances = updatedMaps
                                  .map(_LeaveBalanceItem.fromJson)
                                  .toList();
                            });
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            if (mounted) {
                              setState(
                                () => _success =
                                    'Leave allocation updated for ${teacher.name}.',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _error = e.toString());
                            }
                          } finally {
                            setDlgState(() => saving = false);
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save Allocation'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: '',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminPageHeader(
              title: 'Teacher assignments',
              subtitle:
                  'Search by teacher or by class, then load assignments for this year.',
              primaryAction: _canManage
                  ? FilledButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('Assign teacher'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminColors.primaryAction,
                        foregroundColor: AdminColors.textOnPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    )
                  : null,
              iconActions: [
                if (_canManage)
                  IconButton(
                    tooltip: 'Add academic year',
                    onPressed: _showAddYearDialog,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
              ],
            ),

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

            AdminFilterCard(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              headerGap: AdminSpacing.xs,
              onReset: _tabController.index == 0
                  ? _resetTeacherScopeFilters
                  : _resetClassScopeFilters,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    key: ValueKey<String?>(
                        'ta_year_${_selectedYearId}_${_years.length}'),
                    initialValue: _selectedYearId,
                    decoration: const InputDecoration(
                      labelText: 'Academic year',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    items: () {
                      final items =
                          _years
                              .map(
                                (y) => DropdownMenuItem<String?>(
                                  value: y['id']?.toString(),
                                  child: Text(
                                    '${y['name']}${y['is_active'] == true ? ' • Active' : ''}',
                                  ),
                                ),
                              )
                              .toList()
                            ..insert(
                              0,
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All years'),
                              ),
                            );
                      return items;
                    }(),
                    onChanged: (v) async {
                      setState(() {
                        _selectedYearId = v;
                        _standards = [];
                        _assignments = [];
                        _filterStandardId = null;
                        _filterSection = null;
                        _filterSections = [];
                      });
                      ref.read(activeAcademicYearProvider.notifier).setYear(v);
                      if (v != null) {
                        final maps = await _repo.listStandardMaps(v);
                        setState(
                          () => _standards =
                              maps.map(_standardDropdown).toList(),
                        );
                      }
                      await _refreshTeacherAssignmentStatus();
                    },
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: AdminColors.borderSubtle,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AdminColors.primaryAction,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: AdminColors.primaryAction,
                      unselectedLabelColor: AdminColors.textSecondary,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.person_search_outlined, size: 18),
                          text: 'By teacher',
                        ),
                        Tab(
                          icon: Icon(Icons.class_outlined, size: 18),
                          text: 'By class',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AdminColors.border),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: AdminColors.primaryAction,
                        backgroundColor: AdminColors.borderSubtle,
                      ),
                    )
                  else if (_tabController.index == 0)
                    _buildTeacherFilter()
                  else
                    _buildClassFilter(),
                ],
              ),
            ),

            const SizedBox(height: AdminSpacing.sm),

            // ── Assignments table ─────────────────────────────────────────
            Expanded(
              child: _assignments.isEmpty
                  ? const AdminEmptyState(
                      icon: Icons.assignment_ind_outlined,
                      title: 'No assignments loaded',
                      message:
                          'Choose year and filters, then tap Load (🔍) to fetch rows for this tab.',
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AdminColors.rowStripe,
                        ),
                        columns: [
                          const DataColumn(label: Text('Teacher')),
                          const DataColumn(label: Text('Contact')),
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
                              DataCell(
                                Text(
                                  a.teacherEmail.isNotEmpty
                                      ? a.teacherEmail
                                      : (a.teacherPhone.isNotEmpty
                                            ? a.teacherPhone
                                            : '-'),
                                ),
                              ),
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
                                          color: AdminColors.primaryAction,
                                        ),
                                        tooltip: 'Edit',
                                        onPressed: () => _showEditDialog(a),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: AdminColors.danger,
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
    final teachers = _visibleTeachers;
    final selectedTeacher = _teachers.cast<_Teacher?>().firstWhere(
      (t) => t?.id == _selectedTeacherId,
      orElse: () => null,
    );
    final pendingCount = _teachers
        .where((t) => _teacherAssignedBySelectionId[t.id] != true)
        .length;
    final assignedCount = _teachers
        .where((t) => _teacherAssignedBySelectionId[t.id] == true)
        .length;

    final teacherDropdown = DropdownButtonFormField<String?>(
      key: ValueKey<String?>(
        'ta_teacher_${_selectedTeacherId}_${_visibleTeachers.length}_$_teacherStatusFilter',
      ),
      initialValue: _selectedTeacherId,
      decoration: const InputDecoration(
        labelText: 'Teacher',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      isExpanded: true,
      items: teachers
          .map(
            (t) => DropdownMenuItem<String?>(
              value: t.id,
              child: Text(
                t.hasProfile
                    ? '${t.name} (${t.employeeCode})'
                    : '${t.name} (${t.employeeCode.isNotEmpty ? t.employeeCode : 'pending id'}) · profile pending',
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedTeacherId = v),
    );

    final statusSegments = SegmentedButton<String>(
      segments: [
        ButtonSegment<String>(
          value: 'PENDING',
          label: Text('Pending ($pendingCount)'),
        ),
        ButtonSegment<String>(
          value: 'ASSIGNED',
          label: Text('Assigned ($assignedCount)'),
        ),
        const ButtonSegment<String>(
          value: 'ALL',
          label: Text('All'),
        ),
      ],
      emptySelectionAllowed: false,
      selected: {_teacherStatusFilter},
      onSelectionChanged: (next) {
        if (next.isEmpty) return;
        setState(() {
          _teacherStatusFilter = next.first;
          _selectedTeacherId = null;
        });
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final loadBtn = Tooltip(
          message: 'Load assignments for the current filters',
          child: FilledButton.tonalIcon(
            onPressed: _loadByTeacher,
            icon: const Text(
              '🔍',
              style: TextStyle(fontSize: 17, height: 1),
            ),
            label: const Text('Load'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (maxW >= 720)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: statusSegments),
                    const SizedBox(width: AdminSpacing.sm),
                    SizedBox(width: 240, child: teacherDropdown),
                    const SizedBox(width: AdminSpacing.sm),
                    Align(
                      alignment: Alignment.center,
                      child: loadBtn,
                    ),
                    if (selectedTeacher != null &&
                        !selectedTeacher.id.startsWith('user:')) ...[
                      const SizedBox(width: AdminSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showTeacherLeaveDialog(selectedTeacher),
                        icon: const Icon(Icons.event_available_outlined, size: 18),
                        label: const Text('Leave'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showReenrollTeacherDialog,
                        icon: const Icon(Icons.autorenew, size: 18),
                        label: const Text('Re-enroll'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: statusSegments,
                  ),
                  const SizedBox(height: AdminSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: teacherDropdown),
                      const SizedBox(width: AdminSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: loadBtn,
                      ),
                    ],
                  ),
                  if (selectedTeacher != null &&
                      !selectedTeacher.id.startsWith('user:')) ...[
                    const SizedBox(height: AdminSpacing.sm),
                    Wrap(
                      spacing: AdminSpacing.sm,
                      runSpacing: AdminSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showTeacherLeaveDialog(selectedTeacher),
                          icon: const Icon(
                            Icons.event_available_outlined,
                            size: 18,
                          ),
                          label: const Text('Leave'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showReenrollTeacherDialog,
                          icon: const Icon(Icons.autorenew, size: 18),
                          label: const Text('Re-enroll'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            if (selectedTeacher != null) ...[
              const SizedBox(height: AdminSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AdminSpacing.md,
                  vertical: AdminSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AdminColors.borderSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: AdminColors.textSecondary,
                    ),
                    const SizedBox(width: AdminSpacing.sm),
                    Expanded(
                      child: Text(
                        [
                          if (selectedTeacher.employeeCode.isNotEmpty)
                            'Emp ${selectedTeacher.employeeCode}',
                          if (selectedTeacher.email.isNotEmpty)
                            selectedTeacher.email,
                          if (selectedTeacher.phone.isNotEmpty)
                            selectedTeacher.phone,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AdminColors.textSecondary,
                              height: 1.35,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildClassFilter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AdminSpacing.sm,
              runSpacing: AdminSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: narrow ? double.infinity : 220,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey<String?>(
                      'ta_fstd_${_filterStandardId}_${_standards.length}',
                    ),
                    initialValue: _filterStandardId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: _standards
                        .map(
                          (s) => DropdownMenuItem<String?>(
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
                        final secMaps = await _repo.listSectionMaps(
                          v,
                          _selectedYearId!,
                        );
                        if (!mounted) return;
                        setState(() => _filterSections =
                            secMaps.map(_sectionDropdown).toList());
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: narrow ? double.infinity : 180,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'ta_fsec_${_filterSection}_${_filterSections.length}_$_filterStandardId',
                    ),
                    initialValue: () {
                      if (_filterSection == null || _filterSection!.isEmpty) {
                        return '';
                      }
                      return _filterSections.any((s) => s.id == _filterSection)
                          ? _filterSection!
                          : '';
                    }(),
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All sections'),
                      ),
                      ..._filterSections.map(
                        (s) => DropdownMenuItem<String>(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: _filterSections.isEmpty
                        ? null
                        : (v) => setState(
                              () => _filterSection =
                                  (v == null || v.isEmpty) ? null : v,
                            ),
                  ),
                ),
                Tooltip(
                  message: 'Load assignments for this class and section',
                  child: FilledButton.tonalIcon(
                    onPressed: _loadByClass,
                    icon: const Text(
                      '🔍',
                      style: TextStyle(fontSize: 17, height: 1),
                    ),
                    label: const Text('Load'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_assignments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AdminSpacing.xs),
                child: Text(
                  '${_assignments.length} assignment${_assignments.length == 1 ? '' : 's'} loaded',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AdminColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
          ],
        );
      },
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
    final bg = isError
        ? AdminColors.dangerSurface
        : AdminColors.success.withValues(alpha: 0.1);
    final border = isError
        ? AdminColors.danger.withValues(alpha: 0.28)
        : AdminColors.success.withValues(alpha: 0.35);
    final iconColor = isError ? AdminColors.danger : AdminColors.success;
    final textColor =
        isError ? AdminColors.textPrimary : AdminColors.textPrimary;
    final dismissColor = AdminColors.textMuted;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: iconColor,
            size: 16,
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: textColor, height: 1.35),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 14, color: dismissColor),
          ),
        ],
      ),
    );
  }
}
