// lib/presentation/settings/screens/settings_screen.dart  [Admin Console]
// Phase 5: Settings module — school configuration, admin management (STAFF_ADMIN only).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// ── Repository ────────────────────────────────────────────────────────────────

class _SettingsRepository {
  _SettingsRepository(this._dio);
  final DioClient _dio;

  Future<List<Map<String, dynamic>>> getSettings() async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.settings,
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> updateSettings(List<Map<String, String>> items) async {
    await _dio.dio.patch<dynamic>(
      ApiConstants.settings,
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

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final _SettingsRepository _repo;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _settings = [];

  @override
  void initState() {
    super.initState();
    _repo = _SettingsRepository(ref.read(dioClientProvider));
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;
  bool get _canManageSettings {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    if (user.role.toUpperCase() == 'STAFF_ADMIN') return true;
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
    final key = keyInput.trim();
    final value = valueInput.trim();
    if (key.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _repo.updateSettings([
        {'key': key, 'value': value},
      ]);
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

  String _settingKey(Map<String, dynamic> item) {
    return item['setting_key']?.toString() ?? item['key']?.toString() ?? '';
  }

  String _settingValue(Map<String, dynamic> item) {
    return item['setting_value']?.toString() ?? item['value']?.toString() ?? '';
  }

  String keyInput = '';
  String valueInput = '';

  Future<void> _openEditSettingDialog(Map<String, dynamic> item) async {
    if (!_canManageSettings) return;
    final key = _settingKey(item);
    final value = _settingValue(item);
    if (key.trim().isEmpty) return;

    final valueCtrl = TextEditingController(text: value);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update "$key"'),
        content: TextField(
          controller: valueCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              keyInput = key;
              valueInput = valueCtrl.text;
              Navigator.of(ctx).pop();
              await _saveSettingItem();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    valueCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Settings',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminPageHeader(
              title: 'Settings',
              subtitle: 'School configuration and system keys.',
              iconActions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.md),
                child: Material(
                  color: AdminColors.dangerSurface,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: AdminColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: AdminSpacing.sm),
                        Expanded(
                          child: SelectableText(
                            _error!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AdminColors.danger),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const AdminLoadingPlaceholder(
                      message: 'Loading settings…',
                      height: 280,
                    )
                  : SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AdminSurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'School',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AdminColors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: AdminSpacing.sm),
                                  Text(
                                    'Mode: single school',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AdminColors.textSecondary,
                                        ),
                                  ),
                                  const SizedBox(height: AdminSpacing.md),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      'School ID',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: AdminColors.textSecondary,
                                          ),
                                    ),
                                    subtitle: Text(
                                      _schoolId ?? 'Not available',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: AdminColors.textPrimary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AdminSpacing.md),
                            AdminSurfaceCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AdminSpacing.md,
                                      AdminSpacing.md,
                                      AdminSpacing.md,
                                      AdminSpacing.sm,
                                    ),
                                    child: Text(
                                      'System settings',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AdminColors.textPrimary,
                                          ),
                                    ),
                                  ),
                                  if (_settings.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        bottom: AdminSpacing.lg,
                                      ),
                                      child: AdminEmptyState(
                                        title: 'No settings loaded',
                                        message:
                                            'Keys will appear here when configured.',
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: _settings.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(
                                            height: 1,
                                            color: AdminColors.border,
                                          ),
                                      itemBuilder: (context, index) {
                                        final item = _settings[index];
                                        final key = _settingKey(item);
                                        final value = _settingValue(item);
                                        return ListTile(
                                          title: Text(
                                            key.isEmpty ? '-' : key,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          subtitle: Text(
                                            value.isEmpty ? '-' : value,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      AdminColors.textSecondary,
                                                ),
                                          ),
                                          trailing: _canManageSettings
                                              ? IconButton(
                                                  tooltip: 'Edit',
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                  ),
                                                  onPressed: () =>
                                                      _openEditSettingDialog(
                                                          item),
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
