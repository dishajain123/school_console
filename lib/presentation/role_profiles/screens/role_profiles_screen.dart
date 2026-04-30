import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../data/models/role_profiles/role_profile_item.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/role_profile_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/data_table_widget.dart';

class RoleProfilesScreen extends ConsumerStatefulWidget {
  const RoleProfilesScreen({super.key});

  @override
  ConsumerState<RoleProfilesScreen> createState() => _RoleProfilesScreenState();
}

class _RoleProfilesScreenState extends ConsumerState<RoleProfilesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  int _page = 1;
  List<Map<String, dynamic>> _years = const [];
  String? _selectedYearId;
  List<Map<String, dynamic>> _standards = const [];
  List<String> _sections = const [];
  String? _selectedStandardId;
  String? _selectedSection;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _page = 1;
        if (_tabController.index != 0) {
          _selectedStandardId = null;
          _selectedSection = null;
          _sections = const [];
        }
      });
    });
    _searchController.addListener(() {
      setState(() {
        _page = 1;
      });
    });
    _loadAcademicYears();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentRole => ['STUDENT', 'TEACHER', 'PARENT'][_tabController.index];
  bool get _isStudentTab => _tabController.index == 0;

  String? get _schoolId => ref.read(authControllerProvider).valueOrNull?.schoolId;

  Future<void> _loadAcademicYears() async {
    final repository = ref.read(roleProfileRepositoryProvider);
    try {
      final years = await repository.listAcademicYears(schoolId: _schoolId);
      if (!mounted) return;
      final preferredYearId = ref.read(activeAcademicYearProvider);
      final preferred = years.where((y) => y['id']?.toString() == preferredYearId).toList();
      final active = years.where((y) => y['is_active'] == true).toList();
      setState(() {
        _years = years;
        _selectedYearId = preferred.isNotEmpty
            ? preferred.first['id']?.toString()
            : active.isNotEmpty
            ? active.first['id']?.toString()
            : (years.isNotEmpty ? years.first['id']?.toString() : null);
      });
      ref.read(activeAcademicYearProvider.notifier).setYear(_selectedYearId);
      await _loadStandards();
    } catch (_) {}
  }

  Future<void> _loadStandards() async {
    final repository = ref.read(roleProfileRepositoryProvider);
    try {
      final standards =
          await repository.listStandards(academicYearId: _selectedYearId);
      if (!mounted) return;
      setState(() => _standards = standards);
    } catch (_) {}
  }

  Future<void> _loadSectionsForStandard(String standardId) async {
    final repository = ref.read(roleProfileRepositoryProvider);
    try {
      final sections = await repository.listSections(
        standardId: standardId,
        academicYearId: _selectedYearId,
      );
      if (!mounted) return;
      setState(() => _sections = sections);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sections = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(roleProfileRepositoryProvider);

    return AdminScaffold(
      title: 'Role Profiles',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Students'),
                Tab(text: 'Teachers'),
                Tab(text: 'Parents'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _selectedYearId,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        border: OutlineInputBorder(),
                      ),
                      items: _years
                          .map(
                            (y) => DropdownMenuItem<String>(
                              value: y['id']?.toString(),
                              child: Text(y['name']?.toString() ?? '-'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        setState(() {
                          _selectedYearId = value;
                          _selectedStandardId = null;
                          _selectedSection = null;
                          _sections = const [];
                          _page = 1;
                        });
                        ref.read(activeAcademicYearProvider.notifier).setYear(value);
                        await _loadStandards();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by name, email, phone or identifier...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (_isStudentTab)
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        value: _selectedStandardId,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          border: OutlineInputBorder(),
                        ),
                        items: _standards
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s['id']?.toString(),
                                child: Text(s['name']?.toString() ?? '-'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          setState(() {
                            _selectedStandardId = value;
                            _selectedSection = null;
                            _sections = const [];
                            _page = 1;
                          });
                          if (value != null) {
                            await _loadSectionsForStandard(value);
                          }
                        },
                      ),
                    ),
                  if (_isStudentTab)
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        value: _selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Section',
                          border: OutlineInputBorder(),
                        ),
                        items: _sections
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(s),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSection = value;
                            _page = 1;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<RoleProfileListData>(
                future: repository.listProfiles(
                  role: _currentRole,
                  search: _searchController.text,
                  // Keep students visible right after approval/profile creation,
                  // even before academic-year enrollment is assigned.
                  academicYearId: null,
                  standardId: _isStudentTab ? _selectedStandardId : null,
                  section: _isStudentTab ? _selectedSection : null,
                  page: _page,
                  pageSize: 20,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        _readableError(snapshot.error),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final data = snapshot.data;
                  final items = data?.items ?? const <RoleProfileItem>[];
                  if (items.isEmpty) {
                    return const Center(child: Text('No role profiles found'));
                  }

                  return AdminDataTable(
                    columns: [
                      'Identifier',
                      'Full Name',
                      'Email',
                      'Phone',
                      'Details',
                      if (_currentRole == 'PARENT') 'Actions',
                    ],
                    rows: items
                        .map(
                          (item) => _buildRow(
                            item,
                            includeActions: _currentRole == 'PARENT',
                          ),
                        )
                        .toList(),
                    totalItems: data?.total ?? items.length,
                    currentPage: data?.page ?? 1,
                    pageSize: data?.pageSize ?? 20,
                    onPageChanged: (nextPage) {
                      setState(() {
                        _page = nextPage;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(
    RoleProfileItem item, {
    bool includeActions = false,
  }) {
    final identifier = item.identifier ?? item.admissionNumber ?? item.employeeId ?? item.parentCode ?? '-';
    final details = _detailsText(item);
    final cells = <DataCell>[
      DataCell(SelectableText(identifier)),
      DataCell(SelectableText(item.fullName?.trim().isNotEmpty == true ? item.fullName! : '-')),
      DataCell(SelectableText(item.email?.trim().isNotEmpty == true ? item.email! : '-')),
      DataCell(SelectableText(item.phone?.trim().isNotEmpty == true ? item.phone! : '-')),
      DataCell(SelectableText(details)),
    ];
    if (includeActions) {
      cells.add(
        DataCell(
          OutlinedButton(
            onPressed: () => _openParentLinkDialog(item),
            child: const Text('Link Children'),
          ),
        ),
      );
    }

    return DataRow(
      cells: cells,
    );
  }

  Future<void> _openParentLinkDialog(RoleProfileItem parentItem) async {
    final repository = ref.read(roleProfileRepositoryProvider);
    final parentId = (parentItem.raw['parent_id'] ?? '').toString();
    if (parentId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parent profile id is missing.')),
      );
      return;
    }

    final existingIds = await repository.getParentChildIds(parentId);
    final selected = <String>{...existingIds};
    final searchCtrl = TextEditingController();
    List<RoleProfileItem> candidates = [];
    bool loading = false;

    Future<void> loadCandidates(StateSetter setLocal) async {
      setLocal(() => loading = true);
      try {
        final result = await repository.listProfiles(
          role: 'STUDENT',
          search: searchCtrl.text,
          page: 1,
          pageSize: 300,
        );
        candidates = result.items.where((item) {
          final sid = (item.raw['student_id'] ?? '').toString();
          final enrolled = item.raw['enrollment_completed'] == true;
          return sid.isNotEmpty && enrolled;
        }).toList();
      } finally {
        setLocal(() => loading = false);
      }
    }

    // Load student candidates immediately so approved students are visible
    // without requiring an initial search.
    final initial = await repository.listProfiles(
      role: 'STUDENT',
      page: 1,
      pageSize: 300,
    );
    candidates = initial.items.where((item) {
      final sid = (item.raw['student_id'] ?? '').toString();
      final enrolled = item.raw['enrollment_completed'] == true;
      return sid.isNotEmpty && enrolled;
    }).toList();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Link Children: ${parentItem.fullName ?? 'Parent'}'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Search student by name or admission number',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => loadCandidates(setLocal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => loadCandidates(setLocal),
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Selected: ${selected.length}'),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setLocal(() {
                          for (final s in candidates) {
                            final sid = (s.raw['student_id'] ?? '').toString();
                            if (sid.isNotEmpty) selected.add(sid);
                          }
                        });
                      },
                      child: const Text('Select all shown'),
                    ),
                    TextButton(
                      onPressed: () => setLocal(() => selected.clear()),
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : candidates.isEmpty
                          ? const Center(
                              child: Text(
                                'No enrolled students found yet. Create student profile and complete enrollment first.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: candidates.length,
                              itemBuilder: (context, index) {
                                final s = candidates[index];
                                final studentId = (s.raw['student_id'] ?? '').toString();
                                final selectionKey = studentId;
                                if (selectionKey.isEmpty) return const SizedBox.shrink();
                                final checked = selected.contains(selectionKey);
                                final sub = (s.admissionNumber ?? s.identifier ?? '-');
                                return CheckboxListTile(
                                  value: checked,
                                  title: Text(s.fullName?.isNotEmpty == true ? s.fullName! : '-'),
                                  subtitle: Text(sub),
                                  onChanged: (v) {
                                    setLocal(() {
                                      if (v == true) {
                                        selected.add(selectionKey);
                                      } else {
                                        selected.remove(selectionKey);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
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
                final resolvedStudentIds = selected.toList();
                await repository.assignParentChildren(
                  parentId: parentId,
                  studentIds: resolvedStudentIds,
                );
                if (!mounted || !ctx.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Children linked successfully.')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _detailsText(RoleProfileItem item) {
    if (item.role == 'STUDENT') {
      final sec = item.section == null || item.section!.isEmpty ? '-' : item.section!;
      return 'Section: $sec';
    }
    if (item.role == 'TEACHER') {
      return item.specialization == null || item.specialization!.isEmpty
          ? 'Teacher profile'
          : item.specialization!;
    }
    return item.occupation == null || item.occupation!.isEmpty
        ? (item.relation ?? 'Parent profile')
        : item.occupation!;
  }

  String _readableError(Object? error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      if (code == 422) {
        return 'Unable to load profiles. Please check school setup and try again.';
      }
      if (code == 401 || code == 403) {
        return 'You do not have permission to view role profiles.';
      }
      final detail = error.response?.data;
      if (detail is Map && detail['detail'] != null) {
        return detail['detail'].toString();
      }
      return 'Failed to load role profiles. Please try again.';
    }
    return error?.toString() ?? 'Failed to load role profiles.';
  }
}
