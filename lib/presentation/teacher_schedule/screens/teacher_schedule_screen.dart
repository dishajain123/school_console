// lib/presentation/teacher_schedule/screens/teacher_schedule_screen.dart  [Mobile App]
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
// Navigation: pushed from the teacher home screen or via bottom nav.
// Call: context.push('/my-schedule');

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';

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
      '${ApiConstants.teacherAssignments}/mine',
      queryParameters: {
        if (yearId != null) 'academic_year_id': yearId,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Class Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Year filter
          if (_years.isNotEmpty)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Academic Year: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: dropdownYearValue,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: _years
                          .map((y) => DropdownMenuItem<String>(
                                value: y['id']?.toString(),
                                child: Text(
                                  '${y['name']}${y['is_active'] == true ? ' ✓' : ''}',
                                ),
                              ))
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
                ],
              ),
            ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorBody(error: _error!, onRetry: _load)
                    : _assignments.isEmpty
                        ? _EmptyBody(yearName: _selectedYearName)
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Summary chip
                              Wrap(
                                spacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                        '${grouped.length} class${grouped.length == 1 ? '' : 'es'}'),
                                    backgroundColor:
                                        Colors.blue.shade50,
                                    labelStyle: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 12),
                                  ),
                                  Chip(
                                    label: Text(
                                        '${_assignments.length} subject${_assignments.length == 1 ? '' : 's'}'),
                                    backgroundColor:
                                        Colors.green.shade50,
                                    labelStyle: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Grouped cards
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.class_outlined,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  classSection,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${subjects.length} subject${subjects.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Subject rows
          ...subjects.map(
            (s) => ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                child: Text(
                  s.subjectCode.substring(0,
                      s.subjectCode.length > 2 ? 2 : s.subjectCode.length),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer,
                  ),
                ),
              ),
              title: Text(s.subjectName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('Code: ${s.subjectCode}',
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty & Error states ──────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({this.yearName});
  final String? yearName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.assignment_ind_outlined,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            yearName != null
                ? 'No assignments found for $yearName.'
                : 'No assignments found.',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Contact your administrator to assign you to a class.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}