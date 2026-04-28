import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../data/models/role_profiles/role_profile_item.dart';
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
    _loadStandards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentRole => ['STUDENT', 'TEACHER', 'PARENT'][_tabController.index];
  bool get _isStudentTab => _tabController.index == 0;

  Future<void> _loadStandards() async {
    final repository = ref.read(roleProfileRepositoryProvider);
    try {
      final standards = await repository.listStandards();
      if (!mounted) return;
      setState(() => _standards = standards);
    } catch (_) {}
  }

  Future<void> _loadSectionsForStandard(String standardId) async {
    final repository = ref.read(roleProfileRepositoryProvider);
    try {
      final sections = await repository.listSections(standardId: standardId);
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
                    columns: const [
                      'Identifier',
                      'Full Name',
                      'Email',
                      'Phone',
                      'Details',
                    ],
                    rows: items.map((item) => _buildRow(item)).toList(),
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

  DataRow _buildRow(RoleProfileItem item) {
    final identifier = item.identifier ?? item.admissionNumber ?? item.employeeId ?? item.parentCode ?? '-';
    final details = _detailsText(item);

    return DataRow(
      cells: [
        DataCell(Text(identifier)),
        DataCell(Text(item.fullName?.trim().isNotEmpty == true ? item.fullName! : '-')),
        DataCell(Text(item.email?.trim().isNotEmpty == true ? item.email! : '-')),
        DataCell(Text(item.phone?.trim().isNotEmpty == true ? item.phone! : '-')),
        DataCell(Text(details)),
      ],
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
