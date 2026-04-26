import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _page = 1;
      });
    });
    _searchController.addListener(() {
      setState(() {
        _page = 1;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentRole => ['STUDENT', 'TEACHER', 'PARENT'][_tabController.index];

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
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<RoleProfileListData>(
                future: repository.listProfiles(
                  role: _currentRole,
                  search: _searchController.text,
                  page: _page,
                  pageSize: 20,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }

                  final data = snapshot.data;
                  final items = data?.items ?? const <RoleProfileItem>[];
                  if (items.isEmpty) {
                    return const Center(child: Text('No role profiles found'));
                  }

                  return AdminDataTable(
                    columns: const ['Identifier', 'Name', 'Contact', 'Details'],
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
    final contact = item.email ?? item.phone ?? '-';
    final details = _detailsText(item);

    return DataRow(
      cells: [
        DataCell(Text(identifier)),
        DataCell(Text(item.fullName ?? '-')),
        DataCell(Text(contact)),
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
}
