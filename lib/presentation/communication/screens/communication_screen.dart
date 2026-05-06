import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/crash_reporter.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/communication/admin_announcement_models.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/communication_providers.dart';
import '../../../domains/providers/repository_providers.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_filter_card.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

class CommunicationScreen extends ConsumerStatefulWidget {
  const CommunicationScreen({super.key});

  @override
  ConsumerState<CommunicationScreen> createState() =>
      _CommunicationScreenState();
}

class _CommunicationScreenState extends ConsumerState<CommunicationScreen> {
  String? _error;
  String? _success;
  String _visibilityFilter = 'ACTIVE';

  void _resetCommFilters() {
    setState(() {
      _visibilityFilter = 'ACTIVE';
      _error = null;
      _success = null;
    });
  }

  Future<void> _showCreateAnnouncementDialog({
    AdminAnnouncementItem? existing,
    required List<AdminStandardOption> standards,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    String selectedType = existing?.type ?? 'GENERAL';
    String? selectedRole = existing?.targetRole;
    String? selectedStandardId = existing?.targetStandardId;
    final attachmentCtrl =
        TextEditingController(text: existing?.attachmentKey ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title:
              Text(existing == null ? 'Create Announcement' : 'Edit Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bodyCtrl,
                  decoration: const InputDecoration(labelText: 'Content *'),
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    'GENERAL',
                    'URGENT',
                    'FEE',
                    'EXAM',
                    'EVENT',
                    'HOLIDAY',
                  ]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Target Role (optional — all if blank)',
                  ),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('All Roles')),
                    DropdownMenuItem(value: 'STUDENT', child: Text('Students')),
                    DropdownMenuItem(value: 'PARENT', child: Text('Parents')),
                    DropdownMenuItem(value: 'TEACHER', child: Text('Teachers')),
                  ],
                  onChanged: (v) => setDialog(() => selectedRole = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: selectedStandardId,
                  decoration: const InputDecoration(
                    labelText: 'Target Class (optional — all if blank)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All Classes')),
                    ...standards.map(
                      (s) =>
                          DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (v) => setDialog(() => selectedStandardId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: attachmentCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Attachment Key (optional)'),
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
                if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop();
                final repo = ref.read(announcementRepositoryProvider);
                try {
                  if (existing == null) {
                    await repo.createAnnouncement(
                      title: titleCtrl.text.trim(),
                      body: bodyCtrl.text.trim(),
                      type: selectedType,
                      targetRole: selectedRole,
                      targetStandardId: selectedStandardId,
                      attachmentKey: attachmentCtrl.text.trim().isEmpty
                          ? null
                          : attachmentCtrl.text.trim(),
                    );
                    if (mounted) {
                      ref.invalidate(announcementsListProvider);
                      setState(() => _success = 'Announcement posted.');
                    }
                  } else {
                    await repo.updateAnnouncement(existing.id, {
                      'title': titleCtrl.text.trim(),
                      'body': bodyCtrl.text.trim(),
                      'type': selectedType,
                      'target_role': selectedRole,
                      'target_standard_id': selectedStandardId,
                      'attachment_key': attachmentCtrl.text.trim().isEmpty
                          ? null
                          : attachmentCtrl.text.trim(),
                    });
                    if (mounted) {
                      ref.invalidate(announcementsListProvider);
                      setState(() => _success = 'Announcement updated.');
                    }
                  }
                } catch (e) {
                  if (mounted) setState(() => _error = e.toString());
                }
              },
              child: Text(existing == null ? 'Post' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e, stack) {
      CrashReporter.log(e, stack);
      return iso;
    }
  }

  String _standardLabel(
    List<AdminStandardOption> standards,
    String? standardId,
  ) {
    if (standardId == null || standardId.isEmpty) return 'All Classes';
    for (final s in standards) {
      if (s.id == standardId) return s.name;
    }
    return standardId;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final announcementsAsync = ref.watch(announcementsListProvider);
    final standards =
        ref.watch(announcementStandardsProvider).valueOrNull ?? [];
    final canAnnounce = user != null &&
        (user.role.toUpperCase() == 'PRINCIPAL' ||
            user.role.toUpperCase() == 'STAFF_ADMIN' ||
            user.permissions.contains('announcement:create'));

    return AdminScaffold(
      title: 'Communication',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminPageHeader(
              title: 'Communication',
              subtitle:
                  'School-wide announcements by type and audience. Principals and staff admins can publish.',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                child: _StatusBanner(
                  message: _error!,
                  isError: true,
                  onDismiss: () => setState(() => _error = null),
                ),
              ),
            if (_success != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                child: _StatusBanner(
                  message: _success!,
                  isError: false,
                  onDismiss: () => setState(() => _success = null),
                ),
              ),
            Expanded(
              child: announcementsAsync.when(
                loading: () => const AdminLoadingPlaceholder(
                  message: 'Loading announcements…',
                  height: 320,
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.lg),
                    child: SelectableText(
                      e.toString(),
                      style: const TextStyle(color: AdminColors.danger),
                    ),
                  ),
                ),
                data: (announcements) =>
                    _buildAnnouncements(canAnnounce, announcements, standards),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncements(
    bool canCreate,
    List<AdminAnnouncementItem> announcements,
    List<AdminStandardOption> standards,
  ) {
    final filtered = announcements.where((a) {
      if (_visibilityFilter == 'ACTIVE') return a.isActive;
      if (_visibilityFilter == 'DELETED') return !a.isActive;
      return true;
    }).toList(growable: false);
    return Column(
      children: [
        AdminFilterCard(
          onReset: _resetCommFilters,
          child: Row(
            children: [
              Text(
                '${filtered.length} announcement(s)',
                style: const TextStyle(color: AdminColors.textSecondary),
              ),
              const SizedBox(width: AdminSpacing.sm),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: _visibilityFilter,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'View',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(value: 'DELETED', child: Text('Deleted')),
                    DropdownMenuItem(value: 'ALL', child: Text('All')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _visibilityFilter = v);
                  },
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                onPressed: () => ref.invalidate(announcementsListProvider),
              ),
              if (canCreate) ...[
                const SizedBox(width: AdminSpacing.xs),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New announcement'),
                  onPressed: () => _showCreateAnnouncementDialog(
                    standards: standards,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (filtered.isEmpty)
          const Expanded(
            child: AdminEmptyState(
              icon: Icons.campaign_outlined,
              title: 'No announcements',
              message: 'Nothing matches the current view filter.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, ignored) =>
                  const Divider(height: 1, color: AdminColors.border),
              itemBuilder: (context, i) {
                final a = filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: a.typeColor.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.campaign_outlined,
                      size: 16,
                      color: a.typeColor,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: a.typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          a.type,
                          style: TextStyle(
                            color: a.typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!a.isActive) ...[
                        const SizedBox(width: 4),
                        const Chip(
                          label: Text('Inactive', style: TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (a.targetRole != null || a.targetStandardId != null)
                        Text(
                          'Target: ${a.targetRole ?? 'ALL'} | Class: ${_standardLabel(standards, a.targetStandardId)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AdminColors.primaryAction,
                          ),
                        ),
                      Text(
                        _formatDate(a.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  trailing: canCreate
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showCreateAnnouncementDialog(
                                existing: a,
                                standards: standards,
                              );
                              return;
                            }
                            if (value == 'delete') {
                              final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Announcement'),
                                      content: const Text(
                                        'This will deactivate the announcement. Continue?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AdminColors.danger,
                                            foregroundColor:
                                                AdminColors.textOnPrimary,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (!ok || !mounted) return;
                              try {
                                await ref
                                    .read(announcementRepositoryProvider)
                                    .deleteAnnouncement(a.id);
                                ref.invalidate(announcementsListProvider);
                                if (mounted) {
                                  setState(() => _success = 'Announcement deleted.');
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _error = e.toString());
                                }
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        )
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isError
          ? AdminColors.dangerSurface
          : AdminColors.success.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.md,
          vertical: AdminSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isError ? AdminColors.danger : AdminColors.success,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: AdminColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
