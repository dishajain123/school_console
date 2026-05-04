// lib/presentation/teacher_schedule/screens/teacher_schedule_screen.dart  [Admin Console]
// Phase 4 — Teacher Class Schedule / My Assignments.
// Shows a teacher their current academic year class-subject-section assignments.
// This directly reflects whatever the admin has assigned via the admin console.
// When admin changes a teacher's assignment, the teacher sees the updated data
// immediately on next load (no caching).
//
// APIs used:
//   GET /teacher-assignments/mine?academic_year_id={id}
//     Returns TeacherAssignmentListResponse:
//       { items: [ { id, section, teacher:{...},
//                    standard:{id, name, level},
//                    subject:{id, name, code},
//                    academic_year:{id, name},
//                    created_at, updated_at } ], total }
//   GET /academic-years — to populate year filter
//
// Navigation: shell route (sidebar) or deep link.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_filter_card.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _ClassAssignment {
  const _ClassAssignment({
    required this.id,
    required this.standardName,
    required this.standardLevel,
    required this.section,
    required this.subjectName,
    required this.subjectCode,
    required this.academicYearName,
    required this.academicYearId,
    required this.updatedAt,
  });

  final String id;
  final String standardName;
  final int standardLevel;
  final String section;
  final String subjectName;
  final String subjectCode;
  final String academicYearName;
  final String academicYearId;
  final String updatedAt;

  factory _ClassAssignment.fromJson(Map<String, dynamic> j) =>
      _ClassAssignment(
        id: j['id']?.toString() ?? '',
        standardName: j['standard']?['name']?.toString() ?? '',
        standardLevel:
            (j['standard']?['level'] as num?)?.toInt() ?? 0,
        section: j['section']?.toString() ?? '',
        subjectName: j['subject']?['name']?.toString() ?? '',
        subjectCode: j['subject']?['code']?.toString() ?? '',
        academicYearName:
            j['academic_year']?['name']?.toString() ?? '',
        academicYearId:
            j['academic_year']?['id']?.toString() ?? '',
        updatedAt: j['updated_at']?.toString() ?? '',
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class _ScheduleRepository {
  _ScheduleRepository(this._dio);
  final DioClient _dio;

  Future<List<_ClassAssignment>> fetchMine(String? yearId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.teacherAssignmentsMine,
      queryParameters: {
        ...?yearId != null ? {'academic_year_id': yearId} : null,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items
        .map((e) => _ClassAssignment.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchYears(String? schoolId) async {
    if (schoolId == null) return [];
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.academicYears,
      queryParameters: {'school_id': schoolId},
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TeacherScheduleScreen extends ConsumerStatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  ConsumerState<TeacherScheduleScreen> createState() =>
      _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState
    extends ConsumerState<TeacherScheduleScreen> {
  late final _ScheduleRepository _repo;

  List<Map<String, dynamic>> _years = [];
  String? _selectedYearId;
  String? _selectedYearName;

  List<_ClassAssignment> _assignments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = _ScheduleRepository(ref.read(dioClientProvider));
    _init();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final years = await _repo.fetchYears(_schoolId);
      final active = years.firstWhere(
        (y) => y['is_active'] == true,
        orElse: () => years.isNotEmpty ? years.first : {},
      );
      final resolvedYearId = active.isNotEmpty ? active['id']?.toString() : null;
      final validYearId = years.any((y) => y['id']?.toString() == resolvedYearId)
          ? resolvedYearId
          : null;
      setState(() {
        _years = years;
        _selectedYearId = validYearId;
        _selectedYearName = active.isNotEmpty
            ? active['name']?.toString()
            : null;
      });
      await _load();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _resetYearFilter() {
    final active = _years.firstWhere(
      (y) => y['is_active'] == true,
      orElse: () => _years.isNotEmpty ? _years.first : {},
    );
    if (active.isEmpty) return;
    setState(() {
      _selectedYearId = active['id']?.toString();
      _selectedYearName = active['name']?.toString();
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.fetchMine(_selectedYearId);
      setState(() => _assignments = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // Group by standard+section for display
  Map<String, List<_ClassAssignment>> get _grouped {
    final map = <String, List<_ClassAssignment>>{};
    for (final a in _assignments) {
      final key = '${a.standardName} — Section ${a.section}';
      map.putIfAbsent(key, () => []).add(a);
    }
    return Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) {
          final levelA = a.value.first.standardLevel;
          final levelB = b.value.first.standardLevel;
          final cmp = levelA.compareTo(levelB);
          if (cmp != 0) return cmp;
          return a.value.first.section.compareTo(b.value.first.section);
        }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dropdownYearValue = _years.any((y) => y['id']?.toString() == _selectedYearId)
        ? _selectedYearId
        : null;
    final grouped = _grouped;

    return AdminScaffold(
      title: 'My class schedule',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminPageHeader(
              title: 'My class schedule',
              subtitle:
                  'Assignments for the selected academic year, grouped by class and section.',
              iconActions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (_years.isNotEmpty)
              AdminFilterCard(
                onReset: _resetYearFilter,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey<String?>(
                    'ts_year_${dropdownYearValue}_${_years.length}',
                  ),
                  initialValue: dropdownYearValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Academic year',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: _years
                      .map(
                        (y) => DropdownMenuItem<String?>(
                          value: y['id']?.toString(),
                          child: Text(
                            '${y['name']}${y['is_active'] == true ? ' • Active' : ''}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final name = _years
                        .firstWhere(
                          (y) => y['id']?.toString() == v,
                          orElse: () => {},
                        )['name']
                        ?.toString();
                    setState(() {
                      _selectedYearId = v;
                      _selectedYearName = name;
                    });
                    _load();
                  },
                ),
              ),
            if (_years.isNotEmpty) const SizedBox(height: AdminSpacing.sm),
            Expanded(
              child: _loading
                  ? const AdminLoadingPlaceholder(
                      message: 'Loading your schedule…',
                      height: 320,
                    )
                  : _error != null
                      ? _ErrorBody(error: _error!, onRetry: _load)
                      : _assignments.isEmpty
                          ? AdminEmptyState(
                              icon: Icons.calendar_today_outlined,
                              title: 'No assignments',
                              message: _selectedYearName != null
                                  ? 'No assignments found for $_selectedYearName. Pick another year or ask an administrator.'
                                  : 'No assignments found. Ask an administrator to assign you to classes.',
                            )
                          : ListView(
                              padding: const EdgeInsets.only(
                                bottom: AdminSpacing.lg,
                              ),
                              children: [
                                Wrap(
                                  spacing: AdminSpacing.sm,
                                  runSpacing: AdminSpacing.sm,
                                  children: [
                                    Chip(
                                      label: Text(
                                        '${grouped.length} class${grouped.length == 1 ? '' : 'es'}',
                                      ),
                                      backgroundColor: AdminColors.primarySubtle,
                                      side: const BorderSide(
                                        color: AdminColors.border,
                                      ),
                                      labelStyle: const TextStyle(
                                        color: AdminColors.primaryPressed,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        '${_assignments.length} subject${_assignments.length == 1 ? '' : 's'}',
                                      ),
                                      backgroundColor: AdminColors.success
                                          .withValues(alpha: 0.1),
                                      side: const BorderSide(
                                        color: AdminColors.border,
                                      ),
                                      labelStyle: const TextStyle(
                                        color: AdminColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AdminSpacing.md),
                                ...grouped.entries.map(
                                  (entry) => _ClassCard(
                                    classSection: entry.key,
                                    subjects: entry.value,
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

// ── Class Card ────────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  const _ClassCard(
      {required this.classSection, required this.subjects});

  final String classSection;
  final List<_ClassAssignment> subjects;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.md,
              vertical: AdminSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AdminColors.primarySubtle,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.class_outlined,
                  size: 18,
                  color: AdminColors.primaryPressed,
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    classSection,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.surface.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AdminColors.primaryAction.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${subjects.length} subject${subjects.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.primaryPressed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...subjects.map(
            (s) => ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: AdminColors.rowStripe,
                child: Text(
                  s.subjectCode.substring(
                    0,
                    s.subjectCode.length > 2 ? 2 : s.subjectCode.length,
                  ),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AdminColors.primaryAction,
                  ),
                ),
              ),
              title: Text(
                s.subjectName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AdminColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Code: ${s.subjectCode}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ─────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: AdminColors.dangerSurface,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AdminColors.danger,
                        size: 28,
                      ),
                      const SizedBox(width: AdminSpacing.sm),
                      Text(
                        'Could not load schedule',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AdminColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AdminSpacing.sm),
                  SelectableText(
                    error,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AdminColors.danger,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      onPressed: onRetry,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
