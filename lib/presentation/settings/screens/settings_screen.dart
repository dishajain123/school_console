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

  Future<List<Map<String, dynamic>>> getSettings() async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      '/settings',
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> updateSettings(List<Map<String, String>> items) async {
    await _dio.dio.patch<dynamic>(
      '/settings',
      data: {'items': items},
    );
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
  String? _error;
  List<Map<String, dynamic>> _settings = [];
  final _newKeyCtrl = TextEditingController();
  final _newValueCtrl = TextEditingController();

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
    _newKeyCtrl.dispose();
    _newValueCtrl.dispose();
    super.dispose();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;
  bool get _canManageSettings {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    if (user.role.toUpperCase() == 'SUPERADMIN') return true;
    return user.permissions.contains('settings:manage');
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _settings = await _repo.getSettings();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettingItem() async {
    final key = _newKeyCtrl.text.trim();
    final value = _newValueCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _repo.updateSettings([
        {'key': key, 'value': value},
      ]);
      _newKeyCtrl.clear();
      _newValueCtrl.clear();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setting saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
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
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'School'),
                      Tab(text: 'Config'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ── Single-school info ─────────────────────────────
                        SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'School Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Mode: Single School',
                                  style: TextStyle(color: Colors.green.shade700),
                                ),
                                const SizedBox(height: 12),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('School ID'),
                                  subtitle: Text(_schoolId ?? 'Not available'),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'System Settings',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._settings.map(
                                  (s) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      s['setting_key']?.toString() ??
                                          s['key']?.toString() ??
                                          '',
                                    ),
                                    subtitle: Text(
                                      s['setting_value']?.toString() ??
                                          s['value']?.toString() ??
                                          '',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // ── Config ─────────────────────────────────────────
                        SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Configuration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _newKeyCtrl,
                                  readOnly: !_canManageSettings,
                                  decoration: const InputDecoration(
                                    labelText: 'Setting Key',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _newValueCtrl,
                                  readOnly: !_canManageSettings,
                                  decoration: const InputDecoration(
                                    labelText: 'Setting Value',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 16),
                                if (_canManageSettings)
                                  ElevatedButton(
                                    onPressed: _saveSettingItem,
                                    child: const Text('Save Setting'),
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
