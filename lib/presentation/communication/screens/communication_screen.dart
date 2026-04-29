import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

class _Announcement {
  const _Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isActive,
    required this.createdAt,
    this.targetRole,
    this.targetStandardId,
    this.attachmentKey,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isActive;
  final String createdAt;
  final String? targetRole;
  final String? targetStandardId;
  final String? attachmentKey;

  factory _Announcement.fromJson(Map<String, dynamic> j) => _Announcement(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        type: j['type']?.toString() ?? 'GENERAL',
        isActive: j['is_active'] != false,
        createdAt: j['created_at']?.toString() ?? '',
        targetRole: j['target_role'] as String?,
        targetStandardId: j['target_standard_id']?.toString(),
        attachmentKey: j['attachment_key'] as String?,
      );

  Color get typeColor {
    switch (type.toUpperCase()) {
      case 'URGENT':
        return Colors.red;
      case 'FEE':
        return Colors.orange;
      case 'EXAM':
        return Colors.blue;
      case 'EVENT':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }
}

class _StandardOption {
  const _StandardOption({required this.id, required this.name});
  final String id;
  final String name;
}

class _CommRepository {
  _CommRepository(this._dio);
  final DioClient _dio;

  Future<List<_Announcement>> listAnnouncements(
      {bool includeInactive = true}) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/announcements',
      queryParameters: {'include_inactive': includeInactive},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => _Announcement.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<_Announcement> createAnnouncement({
    required String title,
    required String body,
    required String type,
    String? targetRole,
    String? targetStandardId,
    String? attachmentKey,
  }) async {
    final r = await _dio.dio.post<Map<String, dynamic>>(
      '/announcements',
      data: {
        'title': title,
        'body': body,
        'type': type,
        if (targetRole != null) 'target_role': targetRole,
        if (targetStandardId != null) 'target_standard_id': targetStandardId,
        if (attachmentKey != null && attachmentKey.trim().isNotEmpty)
          'attachment_key': attachmentKey.trim(),
      },
    );
    return _Announcement.fromJson(r.data ?? {});
  }

  Future<void> updateAnnouncement(String id, Map<String, dynamic> payload) async {
    await _dio.dio.patch<dynamic>('/announcements/$id', data: payload);
  }

  Future<void> deleteAnnouncement(String id) async {
    await _dio.dio.delete<dynamic>('/announcements/$id');
  }

  Future<List<Map<String, dynamic>>> listYears() async {
    final r = await _dio.dio.get<Map<String, dynamic>>('/academic-years');
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<_StandardOption>> listStandards({String? academicYearId}) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/masters/standards',
      queryParameters: {
        if (academicYearId != null && academicYearId.isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    final items = ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return items
        .map(
          (m) => _StandardOption(
            id: m['id']?.toString() ?? '',
            name: m['name']?.toString() ?? '-',
          ),
        )
        .where((s) => s.id.isNotEmpty)
        .toList();
  }
}

class CommunicationScreen extends ConsumerStatefulWidget {
  const CommunicationScreen({super.key});

  @override
  ConsumerState<CommunicationScreen> createState() =>
      _CommunicationScreenState();
}

class _CommunicationScreenState extends ConsumerState<CommunicationScreen> {
  late final _CommRepository _repo;

  List<_Announcement> _announcements = [];
  List<_StandardOption> _standards = [];
  bool _loading = false;
  String? _error;
  String? _success;
  String _visibilityFilter = 'ACTIVE';

  @override
  void initState() {
    super.initState();
    _repo = _CommRepository(ref.read(dioClientProvider));
    _loadAnnouncements();
    _loadStandards();
  }

  Future<void> _loadStandards() async {
    try {
      String? yearId = ref.read(activeAcademicYearProvider);
      if (yearId == null) {
        final years = await _repo.listYears();
        final active = years.firstWhere(
          (y) => y['is_active'] == true,
          orElse: () => years.isNotEmpty ? years.first : <String, dynamic>{},
        );
        yearId = active['id']?.toString();
      }
      final list = await _repo.listStandards(academicYearId: yearId);
      if (mounted) setState(() => _standards = list);
    } catch (_) {}
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listAnnouncements();
      setState(() => _announcements = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateAnnouncementDialog({_Announcement? existing}) async {
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
                  value: selectedType,
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
                  value: selectedRole,
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
                  value: selectedStandardId,
                  decoration: const InputDecoration(
                    labelText: 'Target Class (optional — all if blank)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All Classes')),
                    ..._standards.map(
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
                try {
                  if (existing == null) {
                    final created = await _repo.createAnnouncement(
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
                      setState(() {
                        _announcements = [created, ..._announcements];
                        _success = 'Announcement posted.';
                      });
                    }
                  } else {
                    await _repo.updateAnnouncement(existing.id, {
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
                      setState(() {
                        _announcements = _announcements
                            .map((a) => a.id == existing.id
                                ? _Announcement(
                                    id: existing.id,
                                    title: titleCtrl.text.trim(),
                                    body: bodyCtrl.text.trim(),
                                    type: selectedType,
                                    isActive: existing.isActive,
                                    createdAt: existing.createdAt,
                                    targetRole: selectedRole,
                                    targetStandardId: selectedStandardId,
                                    attachmentKey:
                                        attachmentCtrl.text.trim().isEmpty
                                            ? null
                                            : attachmentCtrl.text.trim(),
                                  )
                                : a)
                            .toList();
                        _success = 'Announcement updated.';
                      });
                    }
                  }
                  await _loadAnnouncements();
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
    } catch (_) {
      return iso;
    }
  }

  String _standardLabel(String? standardId) {
    if (standardId == null || standardId.isEmpty) return 'All Classes';
    for (final s in _standards) {
      if (s.id == standardId) return s.name;
    }
    return standardId;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final canAnnounce = user != null &&
        (user.role.toUpperCase() == 'PRINCIPAL' ||
            user.role.toUpperCase() == 'SUPERADMIN' ||
            user.permissions.contains('announcement:create'));

    return AdminScaffold(
      title: 'Communication',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              _StatusBanner(
                message: _error!,
                isError: true,
                onDismiss: () => setState(() => _error = null),
              ),
            if (_success != null)
              _StatusBanner(
                message: _success!,
                isError: false,
                onDismiss: () => setState(() => _success = null),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildAnnouncements(canAnnounce),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncements(bool canCreate) {
    final filtered = _announcements.where((a) {
      if (_visibilityFilter == 'ACTIVE') return a.isActive;
      if (_visibilityFilter == 'DELETED') return !a.isActive;
      return true;
    }).toList(growable: false);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                '${filtered.length} announcement(s)',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  value: _visibilityFilter,
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
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Refresh'),
                onPressed: _loadAnnouncements,
              ),
              if (canCreate) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('New Announcement'),
                  onPressed: () => _showCreateAnnouncementDialog(),
                ),
              ],
            ],
          ),
        ),
        if (filtered.isEmpty)
          const Expanded(child: Center(child: Text('No announcements found.')))
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: a.typeColor.withOpacity(0.15),
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
                          color: a.typeColor.withOpacity(0.12),
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
                          'Target: ${a.targetRole ?? 'ALL'} | Class: ${_standardLabel(a.targetStandardId)}',
                          style: const TextStyle(fontSize: 11, color: Colors.blue),
                        ),
                      Text(
                        _formatDate(a.createdAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: canCreate
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showCreateAnnouncementDialog(existing: a);
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
                                        ElevatedButton(
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
                                await _repo.deleteAnnouncement(a.id);
                                await _loadAnnouncements();
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
    final color = isError ? Colors.red : Colors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color.shade700, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 14, color: color.shade400),
          ),
        ],
      ),
    );
  }
}
