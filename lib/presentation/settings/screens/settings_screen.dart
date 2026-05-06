// lib/presentation/settings/screens/settings_screen.dart  [Admin Console]
// Phase 5: Settings module — school configuration, admin management (STAFF_ADMIN only).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/school_settings_provider.dart';
import '../../../domains/providers/settings_repository_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_surface_card.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saveBusy = false;

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;
  bool get _canManageSettings {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    if (user.role.toUpperCase() == 'STAFF_ADMIN') return true;
    return user.permissions.contains('settings:manage');
  }

  Future<void> _saveSettingItem() async {
    final key = keyInput.trim();
    final value = valueInput.trim();
    if (key.isEmpty) return;
    setState(() => _saveBusy = true);
    try {
      await ref.read(settingsRepositoryProvider).updateSettings([
        {'key': key, 'value': value},
      ]);
      ref.invalidate(schoolSettingsProvider);
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
      if (mounted) setState(() => _saveBusy = false);
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
    final settingsAsync = ref.watch(schoolSettingsProvider);

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
                  onPressed: settingsAsync.isLoading || _saveBusy
                      ? null
                      : () => ref.invalidate(schoolSettingsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Expanded(
              child: settingsAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: false,
                data: (settings) => SingleChildScrollView(
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
                              if (settings.isEmpty)
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
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: settings.length,
                                  separatorBuilder: (_, _) => const Divider(
                                    height: 1,
                                    color: AdminColors.border,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = settings[index];
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
                                              color: AdminColors.textSecondary,
                                            ),
                                      ),
                                      trailing: _canManageSettings
                                          ? IconButton(
                                              tooltip: 'Edit',
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                              onPressed: () =>
                                                  _openEditSettingDialog(item),
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
                loading: () => const AdminLoadingPlaceholder(
                  message: 'Loading settings…',
                  height: 280,
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(top: AdminSpacing.md),
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
                              e.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AdminColors.danger),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(schoolSettingsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
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
