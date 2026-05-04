// lib/presentation/enrollment/screens/class_roster_screen.dart  [Admin Console]
// Phase 6: Class Roster Screen — shows all enrolled students for a class/section/year.
// Was a stub. Replaced with functional implementation consuming GET /enrollments/roster.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/enrollment_provider.dart';
import '../../../data/repositories/enrollment_repository.dart';
import '../../../core/theme/admin_colors.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_filter_card.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_table_helpers.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _RosterStudent {
  const _RosterStudent({
    required this.mappingId,
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.rollNumber,
    required this.sectionName,
    required this.status,
    required this.joinedOn,
    this.parentName,
    this.parentPhone,
    this.latestBehaviour,
  });

  final String mappingId;
  final String studentId;
  final String? studentName;
  final String? admissionNumber;
  final String? rollNumber;
  final String? sectionName;
  final String status;
  final String? joinedOn;
  final String? parentName;
  final String? parentPhone;
  final String? latestBehaviour;

  factory _RosterStudent.fromJson(Map<String, dynamic> json) {
    return _RosterStudent(
      mappingId: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name'] as String?,
      admissionNumber: json['admission_number'] as String?,
      rollNumber: json['roll_number'] as String?,
      sectionName: json['section_name'] as String?,
      status: json['status']?.toString() ?? 'ACTIVE',
      joinedOn: json['joined_on'] as String?,
      parentName:
          (json['parent'] as Map<String, dynamic>?)?['full_name'] as String?,
      parentPhone:
          (json['parent'] as Map<String, dynamic>?)?['phone'] as String?,
      latestBehaviour:
          (json['behaviour_summary']
                  as Map<String, dynamic>?)?['latest_incident_type']
              ?.toString(),
    );
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class _RosterRepository {
  _RosterRepository(this._api);
  final EnrollmentRepository _api;

  Future<List<Map<String, dynamic>>> listYears(String schoolId) async {
    return _api.listAcademicYears(schoolId: schoolId);
  }

  Future<List<Map<String, dynamic>>> listStandards(
    String schoolId,
    String academicYearId,
  ) async {
    return _api.listStandards(
      schoolId: schoolId,
      academicYearId: academicYearId,
    );
  }

  Future<List<Map<String, dynamic>>> listSections(
    String schoolId,
    String standardId,
    String academicYearId,
  ) async {
    return _api.listSections(
      schoolId: schoolId,
      standardId: standardId,
      academicYearId: academicYearId,
    );
  }

  Future<Map<String, dynamic>> getRoster({
    required String standardId,
    required String academicYearId,
    String? sectionId,
  }) async {
    return _api.getRoster(
      standardId: standardId,
      academicYearId: academicYearId,
      sectionId: sectionId,
    );
  }

  Future<Map<String, dynamic>> getStudentById(String studentId) async {
    return _api.getStudentById(studentId);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ClassRosterScreen extends ConsumerStatefulWidget {
  const ClassRosterScreen({super.key});

  @override
  ConsumerState<ClassRosterScreen> createState() => _ClassRosterScreenState();
}

class _ClassRosterScreenState extends ConsumerState<ClassRosterScreen> {
  late final _RosterRepository _repo;

  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];
  List<Map<String, dynamic>> _sections = [];
  List<_RosterStudent> _roster = [];

  String? _selectedYearId;
  String? _selectedStandardId;
  String? _selectedSectionId;

  bool _loading = false;
  String? _error;
  int _activeCount = 0;
  int _leftCount = 0;
  int _totalEnrolled = 0;

  @override
  void initState() {
    super.initState();
    _repo = _RosterRepository(ref.read(enrollmentRepositoryProvider));
    _loadYears();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final years = await _repo.listYears(_schoolId!);
      setState(() => _years = years);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onYearChanged(String? yearId) async {
    if (_schoolId == null || yearId == null) return;
    setState(() {
      _selectedYearId = yearId;
      _selectedStandardId = null;
      _selectedSectionId = null;
      _standards = [];
      _sections = [];
      _roster = [];
      _loading = true;
      _error = null;
    });
    try {
      final stds = await _repo.listStandards(_schoolId!, yearId);
      setState(() => _standards = stds);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onStandardChanged(String? standardId) async {
    if (_schoolId == null || _selectedYearId == null || standardId == null) {
      return;
    }
    setState(() {
      _selectedStandardId = standardId;
      _selectedSectionId = null;
      _sections = [];
      _roster = [];
      _loading = true;
      _error = null;
    });
    try {
      final secs = await _repo.listSections(
        _schoolId!,
        standardId,
        _selectedYearId!,
      );
      setState(() => _sections = secs);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _resetRosterFilters() {
    setState(() {
      _selectedYearId = null;
      _selectedStandardId = null;
      _selectedSectionId = null;
      _standards = [];
      _sections = [];
      _roster = [];
      _error = null;
      _activeCount = 0;
      _leftCount = 0;
      _totalEnrolled = 0;
    });
  }

  Future<void> _loadRoster() async {
    if (_selectedStandardId == null || _selectedYearId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.getRoster(
        standardId: _selectedStandardId!,
        academicYearId: _selectedYearId!,
        sectionId: _selectedSectionId,
      );
      final mappings = (data['mappings'] as List?) ?? [];
      final baseRoster = mappings
          .map(
            (e) => _RosterStudent.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      final enriched = <_RosterStudent>[];
      for (final row in baseRoster) {
        if (row.studentId.isEmpty) {
          enriched.add(row);
          continue;
        }
        try {
          final detail = await _repo.getStudentById(row.studentId);
          final merged = <String, dynamic>{
            ...detail,
            'id': row.mappingId,
            'student_id': row.studentId,
            'student_name': row.studentName,
            'admission_number': row.admissionNumber,
            'roll_number': row.rollNumber,
            'section_name': row.sectionName,
            'status': row.status,
            'joined_on': row.joinedOn,
          };
          enriched.add(_RosterStudent.fromJson(merged));
        } catch (_) {
          enriched.add(row);
        }
      }

      setState(() {
        _roster = enriched;
        _activeCount = (data['active_count'] as num?)?.toInt() ?? 0;
        _leftCount = (data['left_count'] as num?)?.toInt() ?? 0;
        _totalEnrolled = (data['total_enrolled'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Class roster',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminPageHeader(
              title: 'Class roster',
              subtitle:
                  'Load enrolled students for a class, section, and academic year.',
            ),
            AdminFilterCard(
              onReset: _resetRosterFilters,
              child: Wrap(
                spacing: AdminSpacing.sm,
                runSpacing: AdminSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Academic year',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                      onChanged: _onYearChanged,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      value: _selectedStandardId,
                      items: _standards
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s['id']?.toString(),
                              child: Text(s['name']?.toString() ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: _onStandardChanged,
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(
                        labelText: 'Section',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      value: _selectedSectionId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All sections'),
                        ),
                        ..._sections.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s['id']?.toString(),
                            child:
                                Text('Section ${s['name']?.toString() ?? ''}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedSectionId = v),
                    ),
                  ),
                  FilledButton.icon(
                    icon: _loading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Load roster'),
                    onPressed: (_loading || _selectedStandardId == null)
                        ? null
                        : _loadRoster,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                child: Material(
                  color: theme.colorScheme.errorContainer
                      .withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    child: SelectableText(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
            if (_roster.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                child: Wrap(
                  spacing: AdminSpacing.sm,
                  runSpacing: AdminSpacing.sm,
                  children: [
                    Chip(
                      label: Text('Total: $_totalEnrolled'),
                      backgroundColor: AdminColors.borderSubtle,
                    ),
                    Chip(
                      label: Text('Active: $_activeCount'),
                      backgroundColor:
                          AdminColors.success.withValues(alpha: 0.12),
                    ),
                    Chip(
                      label: Text('Left: $_leftCount'),
                      backgroundColor:
                          AdminColors.danger.withValues(alpha: 0.10),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _roster.isEmpty && !_loading
                  ? const AdminEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No roster loaded',
                      message:
                          'Pick academic year, class, optional section, then Load roster.',
                    )
                  : Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: adminTableHeadingRowColor(),
                          horizontalMargin: AdminSpacing.md,
                          columnSpacing: AdminSpacing.lg,
                          columns: const [
                            DataColumn(label: Text('Admission #')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Roll No.')),
                            DataColumn(label: Text('Section')),
                            DataColumn(label: Text('Parent')),
                            DataColumn(label: Text('Behaviour')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Joined on')),
                          ],
                          rows: _roster.asMap().entries.map((entry) {
                            final i = entry.key;
                            final s = entry.value;
                            final statusColor = s.status == 'ACTIVE'
                                ? AdminColors.success
                                : s.status == 'LEFT' ||
                                        s.status == 'TRANSFERRED'
                                    ? AdminColors.danger
                                    : AdminColors.textSecondary;
                            return DataRow(
                              color: adminDataRowColor(i),
                              cells: [
                                DataCell(Text(s.admissionNumber ?? '-')),
                                DataCell(Text(s.studentName ?? '-')),
                                DataCell(Text(s.rollNumber ?? '-')),
                                DataCell(Text(s.sectionName ?? '-')),
                                DataCell(
                                  Text(s.parentName ?? s.parentPhone ?? '-'),
                                ),
                                DataCell(
                                  Text(_formatBehaviour(s.latestBehaviour)),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AdminSpacing.sm,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      s.status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(s.joinedOn ?? '-')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBehaviour(String? value) {
    if (value == null || value.isEmpty) return '-';
    if (value == 'POSITIVE') return 'Positive';
    if (value == 'NEGATIVE') return 'Negative';
    return 'Neutral';
  }
}
