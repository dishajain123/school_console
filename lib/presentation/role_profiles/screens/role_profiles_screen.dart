import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/crash_reporter.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/role_profiles/role_profile_item.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/role_profile_list_provider.dart';
import '../../../domains/providers/repository_providers.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_filter_card.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/data_table_widget.dart';

class RoleProfilesScreen extends ConsumerStatefulWidget {
  const RoleProfilesScreen({super.key});

  @override
  ConsumerState<RoleProfilesScreen> createState() => _RoleProfilesScreenState();
}

class _RoleProfilesScreenState extends ConsumerState<RoleProfilesScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _roleTabs = [
    'STUDENT',
    'TEACHER',
    'PARENT',
    'PRINCIPAL',
    'TRUSTEE',
  ];
  static const int _profilePageSize = 50;
  static const Duration _searchDebounce = Duration(milliseconds: 400);

  late final TabController _tabController;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _years = const [];
  String? _selectedYearId;
  List<Map<String, dynamic>> _standards = const [];
  List<String> _sections = const [];
  String? _selectedStandardId;
  String? _selectedSection;

  int _profilePage = 1;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _roleTabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        if (_tabController.index != 0) {
          _selectedStandardId = null;
          _selectedSection = null;
          _sections = const [];
        }
        _profilePage = 1;
      });
    });
    _searchController.addListener(_onSearchChanged);
    _loadAcademicYears();
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() => _profilePage = 1);
    });
  }

  RoleProfileListQuery _profileQuery() {
    return RoleProfileListQuery(
      role: _currentRole,
      search: _searchController.text,
      standardId: _isStudentTab ? _selectedStandardId : null,
      section: _isStudentTab ? _selectedSection : null,
      page: _profilePage,
      pageSize: _profilePageSize,
    );
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  String get _currentRole => _roleTabs[_tabController.index];
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
    } catch (e, stack) {
      CrashReporter.log(e, stack);
    }
  }

  Future<void> _loadStandards() async {
    final repository = ref.read(roleProfileRepositoryProvider);
    try {
      final standards =
          await repository.listStandards(academicYearId: _selectedYearId);
      if (!mounted) return;
      setState(() => _standards = standards);
    } catch (e, stack) {
      CrashReporter.log(e, stack);
    }
  }

  void _resetFilters() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    ref.read(timedCacheProvider).invalidatePrefix('role_profiles_v1|');
    final preferredYearId = ref.read(activeAcademicYearProvider);
    final preferred =
        _years.where((y) => y['id']?.toString() == preferredYearId).toList();
    final active = _years.where((y) => y['is_active'] == true).toList();
    setState(() {
      _selectedStandardId = null;
      _selectedSection = null;
      _sections = const [];
      _profilePage = 1;
      _selectedYearId = preferred.isNotEmpty
          ? preferred.first['id']?.toString()
          : active.isNotEmpty
              ? active.first['id']?.toString()
              : (_years.isNotEmpty ? _years.first['id']?.toString() : null);
    });
    ref.read(activeAcademicYearProvider.notifier).setYear(_selectedYearId);
    _loadStandards();
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
    } catch (e, stack) {
      CrashReporter.log(e, stack);
      if (!mounted) return;
      setState(() => _sections = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(roleProfileListProvider(_profileQuery()));

    return AdminScaffold(
      title: 'Role profiles',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminPageHeader(
              title: 'Role profiles',
              subtitle:
                  'Browse people by role, narrow students with class and section, then search. Results load in pages — use the pager under the table.',
            ),
            Material(
              color: AdminColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AdminColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AdminColors.primaryAction,
                labelColor: AdminColors.primaryAction,
                unselectedLabelColor: AdminColors.textSecondary,
                dividerColor: const Color(0x00000000),
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Students'),
                  Tab(text: 'Teachers'),
                  Tab(text: 'Parents'),
                  Tab(text: 'Principals'),
                  Tab(text: 'Trustees'),
                ],
              ),
            ),
            const SizedBox(height: AdminSpacing.sm),
            AdminFilterCard(
              onReset: _resetFilters,
              child: Wrap(
                spacing: AdminSpacing.sm,
                runSpacing: AdminSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey<String?>(
                          'rp_year_${_selectedYearId ?? 'null'}_${_years.length}'),
                      initialValue: _selectedYearId,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
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
                          _profilePage = 1;
                        });
                        ref
                            .read(activeAcademicYearProvider.notifier)
                            .setYear(value);
                        await _loadStandards();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText:
                            'Search by name, email, phone or identifier…',
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  if (_isStudentTab)
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey<String?>(
                            'rp_std_${_selectedStandardId ?? 'null'}_${_standards.length}'),
                        initialValue: _selectedStandardId,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: _standards
                            .map(
                              (s) => DropdownMenuItem<String?>(
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
                            _profilePage = 1;
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
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey<String?>(
                            'rp_sec_${_selectedSection ?? 'null'}_${_sections.length}'),
                        initialValue: _selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Section',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: _sections
                            .map(
                              (s) => DropdownMenuItem<String?>(
                                value: s,
                                child: Text(s),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSection = value;
                            _profilePage = 1;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AdminSpacing.sm),
            Expanded(
              child: profilesAsync.when(
                loading: () => const AdminLoadingPlaceholder(
                  message: 'Loading profiles…',
                  height: 320,
                ),
                error: (err, _) => Center(
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
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: AdminColors.danger,
                                    size: 28,
                                  ),
                                  const SizedBox(width: AdminSpacing.sm),
                                  Text(
                                    'Could not load profiles',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AdminColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AdminSpacing.sm),
                              SelectableText(
                                _readableError(err),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AdminColors.danger,
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: AdminSpacing.md),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Retry'),
                                  onPressed: () {
                                    ref.read(timedCacheProvider).invalidatePrefix(
                                      'role_profiles_v1|',
                                    );
                                    ref.invalidate(
                                      roleProfileListProvider(_profileQuery()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                data: (data) {
                  final items = data.items;
                  if (items.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.people_outline,
                      title: 'No profiles match',
                      message:
                          'Change role tab, filters, or search, then try again.',
                    );
                  }

                  final pageIdx = data.page;
                  final pgSize = data.pageSize;
                  final totalPages = data.totalPages > 0
                      ? data.totalPages
                      : (((data.total) / (pgSize.clamp(1, 9999))).ceil());

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
                    totalItems: data.total,
                    currentPage: pageIdx < 1 ? 1 : pageIdx,
                    pageSize: pgSize < 1 ? _profilePageSize : pgSize,
                    showPagination: totalPages > 1,
                    onPageChanged: (nextPage) {
                      setState(() => _profilePage = nextPage);
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
                ref.read(timedCacheProvider).invalidatePrefix('role_profiles_v1|');
                if (!mounted || !ctx.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Children linked successfully.')),
                );
                ref.invalidate(roleProfileListProvider(_profileQuery()));
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
    if (item.role == 'PRINCIPAL') {
      return 'Principal profile';
    }
    if (item.role == 'TRUSTEE') {
      return 'Trustee profile';
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
