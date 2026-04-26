// lib/presentation/role_profiles/screens/role_profiles_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/data_table_widget.dart';
import '../../common/widgets/status_badge.dart';
import '../providers/role_profile_provider.dart';
import '../widgets/pending_profiles_banner.dart';

class RoleProfilesScreen extends ConsumerStatefulWidget {
  const RoleProfilesScreen({super.key});

  @override
  ConsumerState<RoleProfilesScreen> createState() => _RoleProfilesScreenState();
}

class _RoleProfilesScreenState extends ConsumerState<RoleProfilesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentRole => ['STUDENT', 'TEACHER', 'PARENT'][_tabController.index];

  void _loadCurrent() {
    ref.read(roleProfileProvider.notifier).load(role: _currentRole);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roleProfileProvider);
    final pending = ref.watch(pendingProfilesCountProvider);

    return AdminScaffold(
      title: 'Role Profiles',
      actions: [
        pending.maybeWhen(
          data: (count) => count > 0
              ? _PendingBadge(count: count, onTap: () => context.push('/approvals?status=PENDING_PROFILE'))
              : const SizedBox(),
          orElse: () => const SizedBox(),
        ),
        const SizedBox(width: 12),
        _CreateProfileButton(role: _currentRole),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tabs ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => _loadCurrent(),
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: const Color(0xFF6366F1),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Students', icon: Icon(Icons.school_rounded, size: 18)),
                Tab(text: 'Teachers', icon: Icon(Icons.person_rounded, size: 18)),
                Tab(text: 'Parents', icon: Icon(Icons.family_restroom_rounded, size: 18)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Search ──────────────────────────────────────────────
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, ID or contact...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) {
                ref.read(roleProfileProvider.notifier)
                    .load(role: _currentRole, search: val.isEmpty ? null : val);
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Table ────────────────────────────────────────────────
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.red))),
              data: (data) {
                if (data == null || data.items.isEmpty) {
                  return _EmptyProfileState(role: _currentRole);
                }
                return _ProfileTable(
                  role: _currentRole,
                  profiles: data.items,
                  total: data.total,
                  page: data.page,
                  pageSize: data.pageSize,
                  onPageChange: (p) => ref.read(roleProfileProvider.notifier)
                      .load(role: _currentRole, page: p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Table — adapts columns per role ─────────────────────────────────

class _ProfileTable extends StatelessWidget {
  final String role;
  final List<Map<String, dynamic>> profiles;
  final int total, page, pageSize;
  final void Function(int) onPageChange;

  const _ProfileTable({
    required this.role,
    required this.profiles,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    return AdminDataTable(
      columns: _columns(),
      rows: profiles.map((p) => _buildRow(context, p)).toList(),
      totalItems: total,
      currentPage: page,
      pageSize: pageSize,
      onPageChanged: onPageChange,
    );
  }

  List<String> _columns() {
    switch (role) {
      case 'STUDENT':
        return ['Admission No.', 'Name', 'DOB', 'Class', 'Section', 'Admitted', 'Type', ''];
      case 'TEACHER':
        return ['Employee ID', 'Name', 'Email', 'Specialization', 'Join Date', 'Type', ''];
      case 'PARENT':
        return ['Parent Code', 'Name', 'Occupation', 'Relation', 'Children', 'Type', ''];
      default:
        return [];
    }
  }

  DataRow _buildRow(BuildContext context, Map<String, dynamic> p) {
    final isCustom = p['is_identifier_custom'] == true;
    final customBadge = isCustom
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFB923C)),
            ),
            child: const Text('Custom',
                style: TextStyle(
                    color: Color(0xFFEA580C),
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Auto',
                style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          );

    if (role == 'STUDENT') {
      return DataRow(
        onSelectChanged: (_) => context.push('/role-profiles/${p['user_id']}'),
        cells: [
          DataCell(_IdentifierCell(value: p['admission_number'] ?? '-')),
          DataCell(Text(p['name'] ?? '-')),
          DataCell(Text(p['date_of_birth'] ?? '-')),
          DataCell(Text(p['standard_name'] ?? 'Unassigned')),
          DataCell(Text(p['section'] ?? '-')),
          DataCell(Text(p['admission_date'] ?? '-')),
          DataCell(customBadge),
          DataCell(IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onPressed: () => context.push('/role-profiles/${p['user_id']}'),
          )),
        ],
      );
    }
    if (role == 'TEACHER') {
      return DataRow(
        onSelectChanged: (_) => context.push('/role-profiles/${p['user_id']}'),
        cells: [
          DataCell(_IdentifierCell(value: p['employee_id'] ?? '-')),
          DataCell(Text(p['name'] ?? '-')),
          DataCell(Text(p['email'] ?? p['phone'] ?? '-')),
          DataCell(Text(p['specialization'] ?? '-')),
          DataCell(Text(p['join_date'] ?? '-')),
          DataCell(customBadge),
          DataCell(IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onPressed: () => context.push('/role-profiles/${p['user_id']}'),
          )),
        ],
      );
    }
    // PARENT
    return DataRow(
      onSelectChanged: (_) => context.push('/role-profiles/${p['user_id']}'),
      cells: [
        DataCell(_IdentifierCell(value: p['parent_code'] ?? '-')),
        DataCell(Text(p['name'] ?? '-')),
        DataCell(Text(p['occupation'] ?? '-')),
        DataCell(Text(p['relation'] ?? '-')),
        DataCell(Text('${p['children_count'] ?? 0} child(ren)')),
        DataCell(customBadge),
        DataCell(IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onPressed: () => context.push('/role-profiles/${p['user_id']}'),
        )),
      ],
    );
  }
}

class _IdentifierCell extends StatelessWidget {
  final String value;
  const _IdentifierCell({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: 0.5,
          ),
        ),
      ),
    ]);
  }
}

class _EmptyProfileState extends StatelessWidget {
  final String role;
  const _EmptyProfileState({required this.role});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            role == 'STUDENT'
                ? Icons.school_outlined
                : role == 'TEACHER'
                    ? Icons.person_outline_rounded
                    : Icons.family_restroom_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No ${role.toLowerCase()} profiles yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            'Approve registrations first, then create role profiles.',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingBadge({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFB923C)),
        ),
        child: Row(
          children: [
            const Icon(Icons.pending_actions_rounded,
                size: 16, color: Color(0xFFEA580C)),
            const SizedBox(width: 6),
            Text('$count Pending Profiles',
                style: const TextStyle(
                    color: Color(0xFFEA580C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _CreateProfileButton extends StatelessWidget {
  final String role;
  const _CreateProfileButton({required this.role});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => context.push('/role-profiles/create?role=$role'),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text('Create ${_cap(role)} Profile'),
    );
  }

  String _cap(String s) => s[0] + s.substring(1).toLowerCase();
}