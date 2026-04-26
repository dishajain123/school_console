// lib/presentation/settings/screens/settings_screen.dart  [Admin Console]
// Phase 5: Settings module — school configuration, admin management (SUPERADMIN only).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class _SettingsRepository {
  _SettingsRepository(this._dio);
  final DioClient _dio;

  Future<Map<String, dynamic>> getSchool(String schoolId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>('/schools/$schoolId');
    return resp.data ?? {};
  }

  Future<void> updateSchool(String schoolId, Map<String, dynamic> data) async {
    await _dio.dio.patch<dynamic>('/schools/$schoolId', data: data);
  }

  Future<List<Map<String, dynamic>>> listSchools() async {
    final resp = await _dio.dio.get<Map<String, dynamic>>('/schools');
    return ((resp.data?['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getSettings(String schoolId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/settings',
      queryParameters: {'school_id': schoolId},
    );
    return ((resp.data?['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _SettingsRepository _repo;

  bool _loading = false;
  Map<String, dynamic> _school = {};
  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _settings = [];

  final _schoolNameCtrl = TextEditingController();
  final _schoolAddressCtrl = TextEditingController();
  final _schoolPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repo = _SettingsRepository(ref.read(dioClientProvider));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _schoolNameCtrl.dispose();
    _schoolAddressCtrl.dispose();
    _schoolPhoneCtrl.dispose();
    super.dispose();
  }

  String? get _schoolId => ref.read(authControllerProvider).valueOrNull?.schoolId;
  String get _role => ref.read(authControllerProvider).valueOrNull?.role.toUpperCase() ?? '';
  bool get _isSuperAdmin => _role == 'SUPERADMIN';

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      if (_isSuperAdmin) {
        _schools = await _repo.listSchools();
      } else if (_schoolId != null) {
        _school = await _repo.getSchool(_schoolId!);
        _settings = await _repo.getSettings(_schoolId!);
        _schoolNameCtrl.text = _school['name']?.toString() ?? '';
        _schoolAddressCtrl.text = _school['address']?.toString() ?? '';
        _schoolPhoneCtrl.text = _school['phone']?.toString() ?? '';
      }
    } catch (e) {
      // ignore errors gracefully for settings
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSchool() async {
    if (_schoolId == null) return;
    setState(() => _loading = true);
    try {
      await _repo.updateSchool(_schoolId!, {
        if (_schoolNameCtrl.text.trim().isNotEmpty) 'name': _schoolNameCtrl.text.trim(),
        if (_schoolAddressCtrl.text.trim().isNotEmpty) 'address': _schoolAddressCtrl.text.trim(),
        if (_schoolPhoneCtrl.text.trim().isNotEmpty) 'phone': _schoolPhoneCtrl.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('School settings saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Settings',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      const Tab(text: 'School'),
                      if (_isSuperAdmin) const Tab(text: 'All Schools') else const Tab(text: 'Config'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ── School Info ────────────────────────────────────
                        SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('School Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _schoolNameCtrl,
                                  decoration: const InputDecoration(labelText: 'School Name', border: OutlineInputBorder()),
                                  readOnly: !_isSuperAdmin && _role != 'PRINCIPAL',
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _schoolAddressCtrl,
                                  decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                                  maxLines: 2,
                                  readOnly: !_isSuperAdmin && _role != 'PRINCIPAL',
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _schoolPhoneCtrl,
                                  decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                                  readOnly: !_isSuperAdmin && _role != 'PRINCIPAL',
                                ),
                                const SizedBox(height: 20),
                                if (_isSuperAdmin || _role == 'PRINCIPAL')
                                  ElevatedButton(
                                    onPressed: _saveSchool,
                                    child: const Text('Save Changes'),
                                  ),
                                const SizedBox(height: 24),
                                if (_settings.isNotEmpty) ...[
                                  const Text('System Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ..._settings.map(
                                    (s) => ListTile(
                                      title: Text(s['key']?.toString() ?? ''),
                                      subtitle: Text(s['value']?.toString() ?? ''),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // ── All Schools (SuperAdmin) / Config ──────────────
                        _isSuperAdmin
                            ? SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('All Schools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 12),
                                    DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Name')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Created')),
                                      ],
                                      rows: _schools
                                          .map(
                                            (s) => DataRow(cells: [
                                              DataCell(Text(s['name']?.toString() ?? '-')),
                                              DataCell(Text(s['is_active'] == true ? 'Active' : 'Inactive')),
                                              DataCell(Text((s['created_at']?.toString() ?? '').substring(0, 10))),
                                            ]),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              )
                            : const Center(
                                child: Text('Additional configuration options available via Identifier Config in the sidebar.'),
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