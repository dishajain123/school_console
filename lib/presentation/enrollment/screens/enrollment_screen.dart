// lib/presentation/enrollment/screens/enrollment_screen.dart  [Admin Console]
// Phase 4: Assign students to class/section per academic year, view class roster.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Lightweight models ────────────────────────────────────────────────────────

class _EnrollmentMapping {
  const _EnrollmentMapping({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.standardName,
    required this.sectionName,
    required this.rollNumber,
    required this.status,
    required this.academicYearName,
  });

  final String id;
  final String studentId;
  final String? studentName;
  final String? admissionNumber;
  final String? standardName;
  final String? sectionName;
  final String? rollNumber;
  final String status;
  final String? academicYearName;

  factory _EnrollmentMapping.fromJson(Map<String, dynamic> json) {
    return _EnrollmentMapping(
      id: json['id'].toString(),
      studentId: json['student_id'].toString(),
      studentName: json['student_name'] as String?,
      admissionNumber: json['admission_number'] as String?,
      standardName: json['standard_name'] as String?,
      sectionName: json['section_name'] as String?,
      rollNumber: json['roll_number'] as String?,
      status: json['status']?.toString() ?? 'ACTIVE',
      academicYearName: json['academic_year_name'] as String?,
    );
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class _EnrollmentRepository {
  _EnrollmentRepository(this._dio);
  final DioClient _dio;

  Future<List<_EnrollmentMapping>> listRoster({
    required String schoolId,
    required String standardId,
    required String academicYearId,
    String? sectionId,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/enrollments/roster',
      queryParameters: {
        'school_id': schoolId,
        'standard_id': standardId,
        'academic_year_id': academicYearId,
        if (sectionId != null) 'section_id': sectionId,
      },
    );
    final mappings = (resp.data?['mappings'] as List?) ?? [];
    return mappings
        .map((e) => _EnrollmentMapping.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> createMapping({
    required String studentId,
    required String standardId,
    required String academicYearId,
    String? sectionId,
    String? rollNumber,
  }) async {
    await _dio.dio.post<dynamic>(
      '/enrollments/mappings',
      data: {
        'student_id': studentId,
        'standard_id': standardId,
        'academic_year_id': academicYearId,
        if (sectionId != null) 'section_id': sectionId,
        if (rollNumber != null && rollNumber.isNotEmpty) 'roll_number': rollNumber,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listStandards(String schoolId, String academicYearId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/standards',
      queryParameters: {'school_id': schoolId, 'academic_year_id': academicYearId},
    );
    return ((resp.data?['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listSections(String schoolId, String standardId, String academicYearId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/sections',
      queryParameters: {'school_id': schoolId, 'standard_id': standardId, 'academic_year_id': academicYearId},
    );
    return ((resp.data?['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listAcademicYears(String schoolId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/academic-years',
      queryParameters: {'school_id': schoolId},
    );
    return ((resp.data?['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class EnrollmentScreen extends ConsumerStatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  ConsumerState<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends ConsumerState<EnrollmentScreen> {
  late final _EnrollmentRepository _repo;

  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];
  List<Map<String, dynamic>> _sections = [];
  List<_EnrollmentMapping> _roster = [];

  String? _selectedYearId;
  String? _selectedStandardId;
  String? _selectedSectionId;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = _EnrollmentRepository(ref.read(dioClientProvider));
    _loadYears();
  }

  String? get _schoolId => ref.read(authControllerProvider).valueOrNull?.schoolId;

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() => _loading = true);
    try {
      final years = await _repo.listAcademicYears(_schoolId!);
      final active = years.firstWhere((y) => y['is_active'] == true, orElse: () => years.isNotEmpty ? years.first : {});
      setState(() {
        _years = years;
        _selectedYearId = active['id']?.toString();
      });
      if (_selectedYearId != null) await _loadStandards();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStandards() async {
    if (_schoolId == null || _selectedYearId == null) return;
    setState(() => _loading = true);
    try {
      final stds = await _repo.listStandards(_schoolId!, _selectedYearId!);
      setState(() {
        _standards = stds;
        _selectedStandardId = null;
        _sections = [];
        _roster = [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSections(String standardId) async {
    if (_schoolId == null || _selectedYearId == null) return;
    setState(() { _selectedStandardId = standardId; _loading = true; });
    try {
      final secs = await _repo.listSections(_schoolId!, standardId, _selectedYearId!);
      setState(() {
        _sections = secs;
        _selectedSectionId = null;
        _roster = [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRoster() async {
    if (_schoolId == null || _selectedYearId == null || _selectedStandardId == null) return;
    setState(() => _loading = true);
    try {
      final roster = await _repo.listRoster(
        schoolId: _schoolId!,
        standardId: _selectedStandardId!,
        academicYearId: _selectedYearId!,
        sectionId: _selectedSectionId,
      );
      setState(() => _roster = roster);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showEnrollDialog() async {
    final studentIdCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enroll Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: studentIdCtrl, decoration: const InputDecoration(labelText: 'Student ID (UUID)')),
            const SizedBox(height: 8),
            TextField(controller: rollCtrl, decoration: const InputDecoration(labelText: 'Roll Number (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _repo.createMapping(
                  studentId: studentIdCtrl.text.trim(),
                  standardId: _selectedStandardId!,
                  academicYearId: _selectedYearId!,
                  sectionId: _selectedSectionId,
                  rollNumber: rollCtrl.text.trim().isEmpty ? null : rollCtrl.text.trim(),
                );
                await _loadRoster();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student enrolled successfully')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Enroll'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Enrollment',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters row
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      // Year
                      if (_years.isNotEmpty)
                        DropdownButton<String>(
                          value: _selectedYearId,
                          hint: const Text('Academic Year'),
                          items: _years.map((y) => DropdownMenuItem<String>(value: y['id']?.toString(), child: Text(y['name']?.toString() ?? ''))).toList(),
                          onChanged: (v) { setState(() => _selectedYearId = v); _loadStandards(); },
                        ),
                      // Standard
                      if (_standards.isNotEmpty)
                        DropdownButton<String>(
                          value: _selectedStandardId,
                          hint: const Text('Class'),
                          items: _standards.map((s) => DropdownMenuItem<String>(value: s['id']?.toString(), child: Text(s['name']?.toString() ?? ''))).toList(),
                          onChanged: (v) { if (v != null) _loadSections(v); },
                        ),
                      // Section
                      if (_sections.isNotEmpty)
                        DropdownButton<String?>(
                          value: _selectedSectionId,
                          hint: const Text('Section (optional)'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('All Sections')),
                            ..._sections.map((s) => DropdownMenuItem<String?>(value: s['id']?.toString(), child: Text('Section ${s['name']?.toString() ?? ''}'))),
                          ],
                          onChanged: (v) { setState(() => _selectedSectionId = v); },
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Load Roster'),
                        onPressed: _selectedStandardId != null ? _loadRoster : null,
                      ),
                      if (_selectedStandardId != null)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Enroll Student'),
                          onPressed: _showEnrollDialog,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  // Roster table
                  Expanded(
                    child: _roster.isEmpty
                        ? const Center(child: Text('Select a class and load roster to view enrollments'))
                        : SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Admission No.')),
                                DataColumn(label: Text('Student Name')),
                                DataColumn(label: Text('Class')),
                                DataColumn(label: Text('Section')),
                                DataColumn(label: Text('Roll No.')),
                                DataColumn(label: Text('Status')),
                              ],
                              rows: _roster
                                  .map(
                                    (m) => DataRow(cells: [
                                      DataCell(Text(m.admissionNumber ?? '-')),
                                      DataCell(Text(m.studentName ?? '-')),
                                      DataCell(Text(m.standardName ?? '-')),
                                      DataCell(Text(m.sectionName ?? '-')),
                                      DataCell(Text(m.rollNumber ?? '-')),
                                      DataCell(Text(m.status)),
                                    ]),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}