// lib/presentation/academics/screens/academic_structure_screen.dart  [Admin Console]
// Phase 3: Standards (classes) and Sections management.
// Only PRINCIPAL and STAFF_ADMIN can create/edit; STAFF with settings:manage can view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_surface_card.dart';

// ── Simple models ─────────────────────────────────────────────────────────────

class _Standard {
  const _Standard({
    required this.id,
    required this.name,
    required this.level,
    required this.sectionCount,
  });
  final String id;
  final String name;
  final int level;
  final int sectionCount;
}

class _Section {
  const _Section({
    required this.id,
    required this.name,
    required this.capacity,
    required this.standardId,
  });
  final String id;
  final String name;
  final int? capacity;
  final String standardId;
}

class _Subject {
  const _Subject({
    required this.id,
    required this.name,
    required this.code,
    this.standardId,
  });
  final String id;
  final String name;
  final String code;
  final String? standardId;
}

class _ClassAssignment {
  const _ClassAssignment({
    required this.section,
    required this.subjectName,
    required this.teacherName,
    required this.employeeCode,
  });
  final String section;
  final String subjectName;
  final String? teacherName;
  final String employeeCode;
}

// ── Repository ────────────────────────────────────────────────────────────────

class _AcademicStructureRepository {
  _AcademicStructureRepository(this._dio);
  final DioClient _dio;

  Future<List<_Standard>> listStandards({String? academicYearId}) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.standards,
      queryParameters: {
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) {
      final m = e as Map;
      return _Standard(
        id: m['id'].toString(),
        name: m['name'].toString(),
        level: (m['level'] as num?)?.toInt() ?? 0,
        sectionCount: (m['section_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<_Section>> listSections(
    String standardId, {
    String? academicYearId,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.sections,
      queryParameters: {
        'standard_id': standardId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) {
      final m = e as Map;
      return _Section(
        id: m['id'].toString(),
        name: m['name'].toString(),
        capacity: (m['capacity'] as num?)?.toInt(),
        standardId: standardId,
      );
    }).toList();
  }

  Future<void> createStandard({
    required String name,
    required int level,
    required String academicYearId,
  }) async {
    await _dio.dio.post<dynamic>(
      ApiConstants.standards,
      data: {
        'name': name.trim(),
        'level': level,
        'academic_year_id': academicYearId,
      },
    );
  }
  Future<void> updateStandard({
    required String standardId,
    required String name,
    required int level,
    required String academicYearId,
  }) async {
    await _dio.dio.patch<dynamic>(
      ApiConstants.standardById(standardId),
      data: {
        'name': name.trim(),
        'level': level,
        'academic_year_id': academicYearId,
      },
    );
  }

  Future<void> deleteStandard(String standardId) async {
    await _dio.dio.delete<dynamic>(ApiConstants.standardById(standardId));
  }

  Future<void> createSection({
    required String standardId,
    required String academicYearId,
    required String sectionName,
    int? capacity,
  }) async {
    await _dio.dio.post<dynamic>(
      ApiConstants.sections,
      data: {
        'standard_id': standardId,
        'academic_year_id': academicYearId,
        'name': sectionName.trim().toUpperCase(),
        if (capacity != null) 'capacity': capacity,
      },
    );
  }
  Future<void> updateSection({
    required String sectionId,
    required String sectionName,
    int? capacity,
  }) async {
    await _dio.dio.patch<dynamic>(
      ApiConstants.sectionById(sectionId),
      data: {
        'name': sectionName.trim().toUpperCase(),
        'capacity': capacity,
      },
    );
  }

  Future<void> deleteSection(String sectionId) async {
    await _dio.dio.delete<dynamic>(ApiConstants.sectionById(sectionId));
  }

  Future<List<Map<String, dynamic>>> listAcademicYears() async {
    final resp =
        await _dio.dio.get<Map<String, dynamic>>(ApiConstants.academicYears);
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createAcademicYear({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      ApiConstants.academicYears,
      data: {
        'name': name.trim(),
        'start_date': _fmtDate(startDate),
        'end_date': _fmtDate(endDate),
      },
    );
    return Map<String, dynamic>.from(resp.data ?? {});
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<List<_Subject>> listSubjects({String? standardId}) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.subjects,
      queryParameters: {if (standardId != null) 'standard_id': standardId},
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) {
      final m = e as Map;
      return _Subject(
        id: m['id'].toString(),
        name: m['name']?.toString() ?? '',
        code: m['code']?.toString() ?? '',
        standardId: m['standard_id']?.toString(),
      );
    }).toList();
  }

  Future<void> createSubject({
    required String standardId,
    required String name,
    required String code,
  }) async {
    await _dio.dio.post<dynamic>(
      ApiConstants.subjects,
      data: {
        'standard_id': standardId,
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
      },
    );
  }
  Future<void> updateSubject({
    required String subjectId,
    required String standardId,
    required String name,
    required String code,
  }) async {
    await _dio.dio.patch<dynamic>(
      ApiConstants.subjectById(subjectId),
      data: {
        'standard_id': standardId,
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
      },
    );
  }

  Future<void> deleteSubject(String subjectId) async {
    await _dio.dio.delete<dynamic>(ApiConstants.subjectById(subjectId));
  }

  Future<List<_ClassAssignment>> listTeacherAssignmentsForStandard({
    required String standardId,
    required String academicYearId,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.teacherAssignments,
      queryParameters: {
        'standard_id': standardId,
        'academic_year_id': academicYearId,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final teacher = Map<String, dynamic>.from(
        (m['teacher'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      final subject = Map<String, dynamic>.from(
        (m['subject'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      return _ClassAssignment(
        section: m['section']?.toString() ?? '',
        subjectName: subject['name']?.toString() ?? '',
        teacherName: teacher['full_name']?.toString(),
        employeeCode: teacher['employee_code']?.toString() ?? '',
      );
    }).toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AcademicStructureScreen extends ConsumerStatefulWidget {
  const AcademicStructureScreen({super.key});

  @override
  ConsumerState<AcademicStructureScreen> createState() =>
      _AcademicStructureScreenState();
}

class _AcademicStructureScreenState
    extends ConsumerState<AcademicStructureScreen> {
  late final _AcademicStructureRepository _repo;
  List<Map<String, dynamic>> _years = [];
  String? _selectedYearId;
  List<_Standard> _standards = [];
  _Standard? _selectedStandard;
  List<_Section> _sections = [];
  List<_Subject> _subjects = [];
  List<_ClassAssignment> _classAssignments = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final dio = ref.read(dioClientProvider);
    _repo = _AcademicStructureRepository(dio);
    _loadYears();
  }

  Future<void> _loadYears() async {
    setState(() => _loading = true);
    try {
      final years = await _repo.listAcademicYears();
      final active = years.firstWhere(
        (y) => y['is_active'] == true,
        orElse: () => years.isNotEmpty ? years.first : {},
      );
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

  Future<void> _showAddAcademicYearDialog() async {
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
                  final createdId = created['id']?.toString();
                  setState(() {
                    _years = years;
                    _selectedYearId = createdId ?? _selectedYearId;
                  });
                  await _loadStandards();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Academic year added and selected for filtering.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Unable to add year: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStandards() async {
    if (_selectedYearId == null) return;
    setState(() => _loading = true);
    try {
      final standards = await _repo.listStandards(
        academicYearId: _selectedYearId,
      );
      setState(() {
        _standards = standards;
        _selectedStandard = null;
        _sections = [];
        _subjects = [];
        _classAssignments = [];
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSections(_Standard standard) async {
    if (_selectedYearId == null) return;
    setState(() {
      _selectedStandard = standard;
      _loading = true;
    });
    try {
      final sections = await _repo.listSections(
        standard.id,
        academicYearId: _selectedYearId,
      );
      final subjects = await _repo.listSubjects(standardId: standard.id);
      List<_ClassAssignment> assignments = const [];
      try {
        assignments = await _repo.listTeacherAssignmentsForStandard(
          standardId: standard.id,
          academicYearId: _selectedYearId!,
        );
      } on DioException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sections loaded, but teacher mapping could not be loaded: ${e.message ?? 'network error'}',
              ),
            ),
          );
        }
      }
      setState(() {
        _sections = sections;
        _subjects = subjects;
        _classAssignments = assignments;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load class details: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddSubjectDialog() async {
    if (_selectedStandard == null) return;
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Subject to ${_selectedStandard!.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Subject Code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (_selectedStandard == null) return;
              try {
                await _repo.createSubject(
                  standardId: _selectedStandard!.id,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                );
                await _loadSections(_selectedStandard!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subject added to class')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  bool get _canEdit {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    return user.role.toUpperCase() == 'PRINCIPAL' ||
        user.role.toUpperCase() == 'STAFF_ADMIN';
  }

  Future<void> _showAddStandardDialog() async {
    final nameCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Add Class / Standard'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Class Name (e.g. Grade 1)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Class name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: levelCtrl,
                  decoration: const InputDecoration(labelText: 'Level (1-12)'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'Enter a valid number';
                    if (n < 1 || n > 12)
                      return 'Level must be between 1 and 12';
                    return null;
                  },
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
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      if (_selectedYearId == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Select an academic year first'),
                            ),
                          );
                        }
                        return;
                      }
                      setDialog(() => submitting = true);
                      try {
                        await _repo.createStandard(
                          name: nameCtrl.text.trim(),
                          level: int.parse(levelCtrl.text.trim()),
                          academicYearId: _selectedYearId!,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await _loadStandards();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Class created')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      } finally {
                        if (ctx.mounted) setDialog(() => submitting = false);
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
  }

  Future<void> _showAddSectionDialog() async {
    if (_selectedStandard == null) return;
    final nameCtrl = TextEditingController();
    final capacityCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Section to ${_selectedStandard!.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Section Name (e.g. A, B)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: capacityCtrl,
              decoration: const InputDecoration(
                labelText: 'Capacity (optional)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (_selectedYearId == null) return;
              try {
                await _repo.createSection(
                  standardId: _selectedStandard!.id,
                  academicYearId: _selectedYearId!,
                  sectionName: nameCtrl.text.trim(),
                  capacity: int.tryParse(capacityCtrl.text.trim()),
                );
                await _loadSections(_selectedStandard!);
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Section created')),
                  );
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditStandardDialog(_Standard standard) async {
    final nameCtrl = TextEditingController(text: standard.name);
    final levelCtrl = TextEditingController(text: standard.level.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Class Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: levelCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Level'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (_selectedYearId == null) return;
              try {
                await _repo.updateStandard(
                  standardId: standard.id,
                  name: nameCtrl.text.trim(),
                  level: int.parse(levelCtrl.text.trim()),
                  academicYearId: _selectedYearId!,
                );
                await _loadStandards();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unable to update class: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStandard(_Standard standard) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
          'Delete ${standard.name} for this academic year? '
          'If linked data exists, deletion may be blocked.',
        ),
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
    if (ok != true) return;
    try {
      await _repo.deleteStandard(standard.id);
      await _loadStandards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete class: $e')),
        );
      }
    }
  }

  Future<void> _showEditSectionDialog(_Section section) async {
    final nameCtrl = TextEditingController(text: section.name);
    final capCtrl = TextEditingController(
      text: section.capacity?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Section Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: capCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity'),
            ),
          ],
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
                await _repo.updateSection(
                  sectionId: section.id,
                  sectionName: nameCtrl.text,
                  capacity: int.tryParse(capCtrl.text.trim()),
                );
                if (_selectedStandard != null) {
                  await _loadSections(_selectedStandard!);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Section updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unable to update section: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSection(_Section section) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text(
          'Delete section ${section.name} in ${_selectedStandard?.name ?? 'selected class'}? '
          'If linked data exists, deletion may be blocked.',
        ),
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
    if (ok != true) return;
    try {
      await _repo.deleteSection(section.id);
      if (_selectedStandard != null) {
        await _loadSections(_selectedStandard!);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Section deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete section: $e')),
        );
      }
    }
  }

  Future<void> _showEditSubjectDialog(_Subject subject) async {
    final nameCtrl = TextEditingController(text: subject.name);
    final codeCtrl = TextEditingController(text: subject.code);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Subject Code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (_selectedStandard == null) return;
              try {
                await _repo.updateSubject(
                  subjectId: subject.id,
                  standardId: _selectedStandard!.id,
                  name: nameCtrl.text,
                  code: codeCtrl.text,
                );
                await _loadSections(_selectedStandard!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subject updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unable to update subject: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubject(_Subject subject) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text(
          'Delete subject ${subject.name} from ${_selectedStandard?.name ?? 'selected class'}? '
          'If linked data exists, deletion may be blocked.',
        ),
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
    if (ok != true) return;
    try {
      await _repo.deleteSubject(subject.id);
      if (_selectedStandard != null) {
        await _loadSections(_selectedStandard!);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Subject deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete subject: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Class setup',
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(AdminSpacing.pagePadding),
              child: AdminLoadingPlaceholder(
                message: 'Loading classes and sections…',
                height: 320,
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.pagePadding),
                child: Material(
                  color: AdminColors.dangerSurface,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    child: SelectableText(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AdminColors.danger,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(AdminSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AdminPageHeader(
                    title: 'Class setup',
                    subtitle:
                        'Pick an academic year, then manage classes, sections, and subjects for that year.',
                  ),
                  if (_years.isNotEmpty)
                    AdminSurfaceCard(
                      child: Wrap(
                        spacing: AdminSpacing.sm,
                        runSpacing: AdminSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Academic year',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AdminColors.textSecondary,
                            ),
                          ),
                          DropdownButton<String>(
                            value: _selectedYearId,
                            items: _years
                                .map(
                                  (y) => DropdownMenuItem<String>(
                                    value: y['id']?.toString(),
                                    child: Text(y['name']?.toString() ?? ''),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => _selectedYearId = val);
                              _loadStandards();
                            },
                          ),
                          if (_canEdit)
                            OutlinedButton.icon(
                              onPressed: _showAddAcademicYearDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add year'),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AdminSpacing.md),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Standards panel
                        Expanded(
                          child: AdminSurfaceCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  title: Text(
                                    'Classes',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AdminColors.textPrimary,
                                    ),
                                  ),
                                  trailing: _canEdit
                                      ? IconButton(
                                          icon: const Icon(Icons.add),
                                          tooltip: 'Add class',
                                          onPressed: _showAddStandardDialog,
                                        )
                                      : null,
                                ),
                                const Divider(
                                  height: 1,
                                  color: AdminColors.border,
                                ),
                                Expanded(
                                  child: _standards.isEmpty
                                      ? const AdminEmptyState(
                                          icon: Icons.class_outlined,
                                          title: 'No classes yet',
                                          message:
                                              'Add a class for the selected academic year.',
                                        )
                                      : ListView.builder(
                                          itemCount: _standards.length,
                                          itemBuilder: (_, i) {
                                            final s = _standards[i];
                                            return ListTile(
                                              title: Text(s.name),
                                              subtitle: Text(
                                                'Level ${s.level}',
                                              ),
                                              selected:
                                                  _selectedStandard?.id == s.id,
                                              onTap: () => _loadSections(s),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '${s.sectionCount} sections',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (_canEdit)
                                                    PopupMenuButton<String>(
                                                      onSelected: (value) {
                                                        if (value == 'edit') {
                                                          _showEditStandardDialog(
                                                            s,
                                                          );
                                                        } else if (value ==
                                                            'delete') {
                                                          _deleteStandard(s);
                                                        }
                                                      },
                                                      itemBuilder: (_) => const [
                                                        PopupMenuItem(
                                                          value: 'edit',
                                                          child: Text('Edit'),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text('Delete'),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AdminSpacing.md),
                        // Sections panel
                        Expanded(
                          child: AdminSurfaceCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  title: Text(
                                    _selectedStandard != null
                                        ? 'Sections — ${_selectedStandard!.name}'
                                        : 'Sections',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AdminColors.textPrimary,
                                    ),
                                  ),
                                  trailing:
                                      _canEdit && _selectedStandard != null
                                      ? IconButton(
                                          icon: const Icon(Icons.add),
                                          tooltip: 'Add section',
                                          onPressed: _showAddSectionDialog,
                                        )
                                      : null,
                                ),
                                const Divider(
                                  height: 1,
                                  color: AdminColors.border,
                                ),
                                Expanded(
                                  child: _selectedStandard == null
                                      ? const AdminEmptyState(
                                          icon: Icons.touch_app_outlined,
                                          title: 'Select a class',
                                          message:
                                              'Choose a class on the left to load its sections.',
                                        )
                                      : _sections.isEmpty
                                      ? const AdminEmptyState(
                                          icon: Icons.grid_view_outlined,
                                          title: 'No sections yet',
                                          message:
                                              'Add a section for this class using the + action.',
                                        )
                                      : ListView.builder(
                                          itemCount: _sections.length,
                                          itemBuilder: (_, i) {
                                            final sec = _sections[i];
                                            final matches = _classAssignments
                                                .where(
                                                  (a) =>
                                                      a.section.toUpperCase() ==
                                                      sec.name.toUpperCase(),
                                                )
                                                .toList();
                                            final teacherLine = matches.isEmpty
                                                ? 'No teacher assigned yet'
                                                : matches
                                                      .map(
                                                        (a) =>
                                                            '${a.subjectName}: ${a.teacherName?.trim().isNotEmpty == true ? a.teacherName : a.employeeCode}',
                                                      )
                                                      .join('  |  ');
                                            return ListTile(
                                              title: Text(
                                                'Section ${sec.name}',
                                              ),
                                              subtitle: Text(
                                                sec.capacity != null
                                                    ? 'Capacity: ${sec.capacity} • $teacherLine'
                                                    : teacherLine,
                                              ),
                                              trailing: _canEdit
                                                  ? PopupMenuButton<String>(
                                                      onSelected: (value) {
                                                        if (value == 'edit') {
                                                          _showEditSectionDialog(
                                                            sec,
                                                          );
                                                        } else if (value ==
                                                            'delete') {
                                                          _deleteSection(sec);
                                                        }
                                                      },
                                                      itemBuilder: (_) => const [
                                                        PopupMenuItem(
                                                          value: 'edit',
                                                          child: Text('Edit'),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text('Delete'),
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AdminSpacing.md),
                        // Subjects panel
                        Expanded(
                          child: AdminSurfaceCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  title: Text(
                                    _selectedStandard != null
                                        ? 'Subjects — ${_selectedStandard!.name}'
                                        : 'Subjects',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AdminColors.textPrimary,
                                    ),
                                  ),
                                  trailing:
                                      _canEdit && _selectedStandard != null
                                      ? IconButton(
                                          icon: const Icon(Icons.add),
                                          tooltip: 'Add subject',
                                          onPressed: _showAddSubjectDialog,
                                        )
                                      : null,
                                ),
                                const Divider(
                                  height: 1,
                                  color: AdminColors.border,
                                ),
                                Expanded(
                                  child: _selectedStandard == null
                                      ? const AdminEmptyState(
                                          icon: Icons.touch_app_outlined,
                                          title: 'Select a class',
                                          message:
                                              'Choose a class on the left to load its subjects.',
                                        )
                                      : _subjects.isEmpty
                                      ? const AdminEmptyState(
                                          icon: Icons.menu_book_outlined,
                                          title: 'No subjects yet',
                                          message:
                                              'Add a subject for this class using the + action.',
                                        )
                                      : ListView.builder(
                                          itemCount: _subjects.length,
                                          itemBuilder: (_, i) {
                                            final sub = _subjects[i];
                                            return ListTile(
                                              title: Text(sub.name),
                                              subtitle: Text(sub.code),
                                              trailing: _canEdit
                                                  ? PopupMenuButton<String>(
                                                      onSelected: (value) {
                                                        if (value == 'edit') {
                                                          _showEditSubjectDialog(
                                                            sub,
                                                          );
                                                        } else if (value ==
                                                            'delete') {
                                                          _deleteSubject(sub);
                                                        }
                                                      },
                                                      itemBuilder: (_) => const [
                                                        PopupMenuItem(
                                                          value: 'edit',
                                                          child: Text('Edit'),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text('Delete'),
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
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
