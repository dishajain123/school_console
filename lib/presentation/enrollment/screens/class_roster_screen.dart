// lib/presentation/enrollment/screens/class_roster_screen.dart  [Admin Console]
// Phase 6: Class Roster Screen — shows all enrolled students for a class/section/year.
// Was a stub. Replaced with functional implementation consuming GET /enrollments/roster.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/enrollment_provider.dart';
import '../../../data/repositories/enrollment_repository.dart';
import '../../common/layout/admin_scaffold.dart';

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
  });

  final String mappingId;
  final String studentId;
  final String? studentName;
  final String? admissionNumber;
  final String? rollNumber;
  final String? sectionName;
  final String status;
  final String? joinedOn;

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
      String schoolId, String academicYearId) async {
    return _api.listStandards(
      schoolId: schoolId,
      academicYearId: academicYearId,
    );
  }

  Future<List<Map<String, dynamic>>> listSections(
      String schoolId, String standardId, String academicYearId) async {
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

  String? get _schoolId => ref.read(authControllerProvider).valueOrNull?.schoolId;

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() { _loading = true; _error = null; });
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
    if (_schoolId == null || _selectedYearId == null || standardId == null) return;
    setState(() {
      _selectedStandardId = standardId;
      _selectedSectionId = null;
      _sections = [];
      _roster = [];
      _loading = true;
      _error = null;
    });
    try {
      final secs = await _repo.listSections(_schoolId!, standardId, _selectedYearId!);
      setState(() => _sections = secs);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRoster() async {
    if (_selectedStandardId == null || _selectedYearId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.getRoster(
        standardId: _selectedStandardId!,
        academicYearId: _selectedYearId!,
        sectionId: _selectedSectionId,
      );
      final mappings = (data['mappings'] as List?) ?? [];
      setState(() {
        _roster = mappings
            .map((e) => _RosterStudent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
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
    return AdminScaffold(
      title: 'Class Roster',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filter Row ───────────────────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedYearId,
                    items: _years
                        .map((y) => DropdownMenuItem<String>(
                              value: y['id']?.toString(),
                              child: Text(y['name']?.toString() ?? ''),
                            ))
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedStandardId,
                    items: _standards
                        .map((s) => DropdownMenuItem<String>(
                              value: s['id']?.toString(),
                              child: Text(s['name']?.toString() ?? ''),
                            ))
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedSectionId,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('All Sections')),
                      ..._sections.map((s) => DropdownMenuItem<String?>(
                            value: s['id']?.toString(),
                            child: Text('Section ${s['name']?.toString() ?? ''}'),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedSectionId = v),
                  ),
                ),
                ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Load Roster'),
                  onPressed: (_loading || _selectedStandardId == null) ? null : _loadRoster,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Error ────────────────────────────────────────────────────
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            // ── Summary Chips ────────────────────────────────────────────
            if (_roster.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text('Total: $_totalEnrolled'),
                      backgroundColor: Colors.grey.shade200,
                    ),
                    Chip(
                      label: Text('Active: $_activeCount'),
                      backgroundColor: Colors.green.shade100,
                    ),
                    Chip(
                      label: Text('Left: $_leftCount'),
                      backgroundColor: Colors.red.shade100,
                    ),
                  ],
                ),
              ),

            // ── Roster Table ─────────────────────────────────────────────
            Expanded(
              child: _roster.isEmpty && !_loading
                  ? const Center(child: Text('Select a class and click Load Roster.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                        columns: const [
                          DataColumn(label: Text('Admission #')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Roll No.')),
                          DataColumn(label: Text('Section')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Joined On')),
                        ],
                        rows: _roster.map((s) {
                          final statusColor = s.status == 'ACTIVE'
                              ? Colors.green
                              : s.status == 'LEFT' || s.status == 'TRANSFERRED'
                                  ? Colors.red
                                  : Colors.orange;
                          return DataRow(cells: [
                            DataCell(Text(s.admissionNumber ?? '-')),
                            DataCell(Text(s.studentName ?? '-')),
                            DataCell(Text(s.rollNumber ?? '-')),
                            DataCell(Text(s.sectionName ?? '-')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  s.status,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            DataCell(Text(s.joinedOn ?? '-')),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
