// lib/presentation/academics/screens/academic_structure_screen.dart  [Admin Console]
// Phase 3: Standards (classes) and Sections management.
// Only PRINCIPAL and SUPERADMIN can create/edit; STAFF with settings:manage can view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Simple models ─────────────────────────────────────────────────────────────

class _Standard {
  const _Standard({required this.id, required this.name, required this.level, required this.sectionCount});
  final String id;
  final String name;
  final int level;
  final int sectionCount;
}

class _Section {
  const _Section({required this.id, required this.name, required this.capacity, required this.standardId});
  final String id;
  final String name;
  final int? capacity;
  final String standardId;
}

// ── Repository ────────────────────────────────────────────────────────────────

class _AcademicStructureRepository {
  _AcademicStructureRepository(this._dio);
  final DioClient _dio;

  Future<List<_Standard>> listStandards(String schoolId, {String? academicYearId}) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/standards',
      queryParameters: {
        'school_id': schoolId,
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

  Future<List<_Section>> listSections(String schoolId, String standardId, {String? academicYearId}) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/sections',
      queryParameters: {
        'school_id': schoolId,
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
    required String schoolId,
    required String name,
    required int level,
    required String academicYearId,
  }) async {
    await _dio.dio.post<dynamic>(
      '/masters/standards',
      queryParameters: {'school_id': schoolId},
      data: {'name': name.trim(), 'level': level, 'academic_year_id': academicYearId},
    );
  }

  Future<void> createSection({
    required String schoolId,
    required String standardId,
    required String academicYearId,
    required String sectionName,
    int? capacity,
  }) async {
    await _dio.dio.post<dynamic>(
      '/masters/sections',
      queryParameters: {'school_id': schoolId},
      data: {
        'standard_id': standardId,
        'academic_year_id': academicYearId,
        'name': sectionName.trim().toUpperCase(),
        if (capacity != null) 'capacity': capacity,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listAcademicYears(String schoolId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/academic-years',
      queryParameters: {'school_id': schoolId},
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AcademicStructureScreen extends ConsumerStatefulWidget {
  const AcademicStructureScreen({super.key});

  @override
  ConsumerState<AcademicStructureScreen> createState() => _AcademicStructureScreenState();
}

class _AcademicStructureScreenState extends ConsumerState<AcademicStructureScreen> {
  late final _AcademicStructureRepository _repo;
  List<Map<String, dynamic>> _years = [];
  String? _selectedYearId;
  List<_Standard> _standards = [];
  _Standard? _selectedStandard;
  List<_Section> _sections = [];
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
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user?.schoolId == null) return;
    setState(() => _loading = true);
    try {
      final years = await _repo.listAcademicYears(user!.schoolId!);
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

  Future<void> _loadStandards() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user?.schoolId == null || _selectedYearId == null) return;
    setState(() => _loading = true);
    try {
      final standards = await _repo.listStandards(user!.schoolId!, academicYearId: _selectedYearId);
      setState(() {
        _standards = standards;
        _selectedStandard = null;
        _sections = [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSections(_Standard standard) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user?.schoolId == null || _selectedYearId == null) return;
    setState(() { _selectedStandard = standard; _loading = true; });
    try {
      final sections = await _repo.listSections(user!.schoolId!, standard.id, academicYearId: _selectedYearId);
      setState(() => _sections = sections);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  bool get _canEdit {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    return user.role.toUpperCase() == 'PRINCIPAL' || user.role.toUpperCase() == 'SUPERADMIN';
  }

  Future<void> _showAddStandardDialog() async {
    final nameCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final user = ref.read(authControllerProvider).valueOrNull;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Class / Standard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Class Name (e.g. Grade 1)')),
            const SizedBox(height: 8),
            TextField(controller: levelCtrl, decoration: const InputDecoration(labelText: 'Level (numeric order)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (user?.schoolId == null || _selectedYearId == null) return;
              try {
                await _repo.createStandard(
                  schoolId: user!.schoolId!,
                  name: nameCtrl.text.trim(),
                  level: int.tryParse(levelCtrl.text.trim()) ?? 0,
                  academicYearId: _selectedYearId!,
                );
                await _loadStandards();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class created')));
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

  Future<void> _showAddSectionDialog() async {
    if (_selectedStandard == null) return;
    final nameCtrl = TextEditingController();
    final capacityCtrl = TextEditingController();
    final user = ref.read(authControllerProvider).valueOrNull;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Section to ${_selectedStandard!.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Section Name (e.g. A, B)')),
            const SizedBox(height: 8),
            TextField(controller: capacityCtrl, decoration: const InputDecoration(labelText: 'Capacity (optional)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (user?.schoolId == null || _selectedYearId == null) return;
              try {
                await _repo.createSection(
                  schoolId: user!.schoolId!,
                  standardId: _selectedStandard!.id,
                  academicYearId: _selectedYearId!,
                  sectionName: nameCtrl.text.trim(),
                  capacity: int.tryParse(capacityCtrl.text.trim()),
                );
                await _loadSections(_selectedStandard!);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Section created')));
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

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Classes & Sections',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Year selector
                      if (_years.isNotEmpty)
                        Row(
                          children: [
                            const Text('Academic Year: '),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _selectedYearId,
                              items: _years
                                  .map((y) => DropdownMenuItem<String>(
                                        value: y['id']?.toString(),
                                        child: Text(y['name']?.toString() ?? ''),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setState(() => _selectedYearId = val);
                                _loadStandards();
                              },
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Standards panel
                            Expanded(
                              child: Card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      title: const Text('Classes', style: TextStyle(fontWeight: FontWeight.bold)),
                                      trailing: _canEdit
                                          ? IconButton(icon: const Icon(Icons.add), onPressed: _showAddStandardDialog)
                                          : null,
                                    ),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: _standards.isEmpty
                                          ? const Center(child: Text('No classes. Add one above.'))
                                          : ListView.builder(
                                              itemCount: _standards.length,
                                              itemBuilder: (_, i) {
                                                final s = _standards[i];
                                                return ListTile(
                                                  title: Text(s.name),
                                                  subtitle: Text('Level ${s.level}'),
                                                  selected: _selectedStandard?.id == s.id,
                                                  onTap: () => _loadSections(s),
                                                  trailing: Text('${s.sectionCount} sections', style: const TextStyle(fontSize: 12)),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Sections panel
                            Expanded(
                              child: Card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      title: Text(
                                        _selectedStandard != null
                                            ? 'Sections — ${_selectedStandard!.name}'
                                            : 'Sections',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      trailing: _canEdit && _selectedStandard != null
                                          ? IconButton(icon: const Icon(Icons.add), onPressed: _showAddSectionDialog)
                                          : null,
                                    ),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: _selectedStandard == null
                                          ? const Center(child: Text('Select a class to view sections'))
                                          : _sections.isEmpty
                                              ? const Center(child: Text('No sections. Add one above.'))
                                              : ListView.builder(
                                                  itemCount: _sections.length,
                                                  itemBuilder: (_, i) {
                                                    final sec = _sections[i];
                                                    return ListTile(
                                                      title: Text('Section ${sec.name}'),
                                                      subtitle: sec.capacity != null
                                                          ? Text('Capacity: ${sec.capacity}')
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