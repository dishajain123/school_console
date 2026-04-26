// lib/presentation/users/screens/users_management_screen.dart  [Admin Console]
// Phase 5: Centralized user management — list active users by role, view profiles.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/data_table_widget.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _ActiveUser {
  const _ActiveUser({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.email,
    required this.phone,
    required this.identifier,
    required this.isActive,
  });

  final String userId;
  final String? fullName;
  final String role;
  final String? email;
  final String? phone;
  final String? identifier;
  final bool isActive;

  factory _ActiveUser.fromProfileJson(Map<String, dynamic> json) {
    final role = json['role']?.toString() ?? '';
    String? identifier;
    if (role == 'STUDENT') identifier = json['admission_number'] as String?;
    if (role == 'TEACHER') identifier = json['employee_id'] as String?;
    if (role == 'PARENT') identifier = json['parent_code'] as String?;
    return _ActiveUser(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name'] as String?,
      role: role,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      identifier: identifier,
      isActive: true,
    );
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class _UsersRepository {
  _UsersRepository(this._dio);
  final DioClient _dio;

  Future<List<_ActiveUser>> listProfiles({
    required String schoolId,
    required String role,
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/role-profiles',
      queryParameters: {
        'school_id': schoolId,
        'role': role,
        'page': page,
        'page_size': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final items = (resp.data?['items'] as List?) ?? [];
    return items.map((e) => _ActiveUser.fromProfileJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _UsersRepository _repo;
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<_ActiveUser> _users = [];
  int _page = 1;
  static const _pageSize = 20;

  static const _roles = ['STUDENT', 'TEACHER', 'PARENT'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _roles.length, vsync: this);
    _repo = _UsersRepository(ref.read(dioClientProvider));
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() { _page = 1; _users = []; });
        _load();
      }
    });
    _searchCtrl.addListener(() {
      setState(() { _page = 1; });
      _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _currentRole => _roles[_tabController.index];
  String? get _schoolId => ref.read(authControllerProvider).valueOrNull?.schoolId;

  Future<void> _load() async {
    if (_schoolId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final users = await _repo.listProfiles(
        schoolId: _schoolId!,
        role: _currentRole,
        page: _page,
        pageSize: _pageSize,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      setState(() => _users = users);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Users',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              controller: _tabController,
              tabs: _roles.map((r) => Tab(text: r[0] + r.substring(1).toLowerCase() + 's')).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search by name, email, phone or ID...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? const Center(child: Text('No users found'))
                      : AdminDataTable(
                          columns: const ['Identifier', 'Name', 'Role', 'Contact'],
                          rows: _users
                              .map(
                                (u) => DataRow(cells: [
                                  DataCell(Text(u.identifier ?? '-')),
                                  DataCell(Text(u.fullName ?? '-')),
                                  DataCell(Text(u.role)),
                                  DataCell(Text(u.email ?? u.phone ?? '-')),
                                ]),
                              )
                              .toList(),
                          totalItems: _users.length,
                          currentPage: _page,
                          pageSize: _pageSize,
                          onPageChanged: (p) { setState(() => _page = p); _load(); },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}