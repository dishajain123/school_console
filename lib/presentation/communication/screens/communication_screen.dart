// lib/presentation/communication/screens/communication_screen.dart  [Admin Console]
// Phase 12 — Notifications & Communication.
// Tab 1 — Admin Notification Inbox:  GET /notifications, PATCH /notifications/mark-all-read
// Tab 2 — Announcements:             GET /announcements, POST /announcements (create), PATCH update
// Backend: all endpoints fully implemented. This admin console screen was entirely missing.
// Responsibility: Admin sends announcements; system triggers automated alerts to users.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Notification Model ────────────────────────────────────────────────────────

class _Notification {
  const _Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String createdAt;

  factory _Notification.fromJson(Map<String, dynamic> j) => _Notification(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        isRead: j['is_read'] == true,
        createdAt: j['created_at']?.toString() ?? '',
      );
}

// ── Announcement Model ────────────────────────────────────────────────────────

class _Announcement {
  const _Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isActive,
    required this.createdAt,
    this.targetRole,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isActive;
  final String createdAt;
  final String? targetRole;

  factory _Announcement.fromJson(Map<String, dynamic> j) => _Announcement(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        type: j['type']?.toString() ?? 'GENERAL',
        isActive: j['is_active'] != false,
        createdAt: j['created_at']?.toString() ?? '',
        targetRole: j['target_role'] as String?,
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

// ── Repository ────────────────────────────────────────────────────────────────

class _CommRepository {
  _CommRepository(this._dio);
  final DioClient _dio;

  // Notifications
  Future<List<_Notification>> getNotifications({bool? isRead}) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {
        'page': 1,
        'page_size': 50,
        if (isRead != null) 'is_read': isRead,
      },
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => _Notification.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final r = await _dio.dio.get<Map<String, dynamic>>('/notifications/unread-count');
    return (r.data?['unread_count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAllRead() async {
    await _dio.dio.patch<dynamic>('/notifications/mark-all-read');
  }

  Future<void> markRead(List<String> ids) async {
    await _dio.dio.patch<dynamic>(
      '/notifications/mark-read',
      data: {'ids': ids},
    );
  }

  Future<void> clearRead() async {
    await _dio.dio.delete<dynamic>('/notifications/clear-read');
  }

  // Announcements
  Future<List<_Announcement>> listAnnouncements({bool includeInactive = true}) async {
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
  }) async {
    final r = await _dio.dio.post<Map<String, dynamic>>(
      '/announcements',
      data: {
        'title': title,
        'body': body,
        'type': type,
        if (targetRole != null) 'target_role': targetRole,
      },
    );
    return _Announcement.fromJson(r.data ?? {});
  }

  Future<void> updateAnnouncement(
      String id, Map<String, dynamic> payload) async {
    await _dio.dio.patch<dynamic>('/announcements/$id', data: payload);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CommunicationScreen extends ConsumerStatefulWidget {
  const CommunicationScreen({super.key});

  @override
  ConsumerState<CommunicationScreen> createState() =>
      _CommunicationScreenState();
}

class _CommunicationScreenState extends ConsumerState<CommunicationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _CommRepository _repo;

  List<_Notification> _notifications = [];
  List<_Announcement> _announcements = [];
  int _unreadCount = 0;

  bool _loading = false;
  bool? _notifReadFilter;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repo = _CommRepository(ref.read(dioClientProvider));
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadNotifications(), _loadAnnouncements()]);
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifs = await _repo.getNotifications(isRead: _notifReadFilter);
      final count = await _repo.getUnreadCount();
      setState(() {
        _notifications = notifs;
        _unreadCount = count;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
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

  Future<void> _markAllRead() async {
    try {
      await _repo.markAllRead();
      await _loadNotifications();
      if (mounted) setState(() => _success = 'All notifications marked as read.');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _clearRead() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Read Notifications'),
        content: const Text('This will permanently delete all read notifications. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.clearRead();
      await _loadNotifications();
      if (mounted) setState(() => _success = 'Read notifications cleared.');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _showCreateAnnouncementDialog({_Announcement? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    String selectedType = existing?.type ?? 'GENERAL';
    String? selectedRole = existing?.targetRole;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(existing == null ? 'Create Announcement' : 'Edit Announcement'),
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
                  items: const ['GENERAL', 'URGENT', 'FEE', 'EXAM', 'EVENT', 'HOLIDAY']
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
                      labelText: 'Target Role (optional — all if blank)'),
                  items: const [
                    DropdownMenuItem<String?>(
                        value: null, child: Text('All Roles')),
                    DropdownMenuItem(value: 'STUDENT', child: Text('Students')),
                    DropdownMenuItem(value: 'PARENT', child: Text('Parents')),
                    DropdownMenuItem(value: 'TEACHER', child: Text('Teachers')),
                  ],
                  onChanged: (v) => setDialog(() => selectedRole = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    bodyCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  if (existing == null) {
                    await _repo.createAnnouncement(
                      title: titleCtrl.text.trim(),
                      body: bodyCtrl.text.trim(),
                      type: selectedType,
                      targetRole: selectedRole,
                    );
                    if (mounted) setState(() => _success = 'Announcement posted.');
                  } else {
                    await _repo.updateAnnouncement(existing.id, {
                      'title': titleCtrl.text.trim(),
                      'body': bodyCtrl.text.trim(),
                      'type': selectedType,
                      if (selectedRole != null) 'target_role': selectedRole,
                    });
                    if (mounted) setState(() => _success = 'Announcement updated.');
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
            // ── Status Messages ───────────────────────────────────────────
            if (_error != null)
              _StatusBanner(message: _error!, isError: true,
                  onDismiss: () => setState(() => _error = null)),
            if (_success != null)
              _StatusBanner(message: _success!, isError: false,
                  onDismiss: () => setState(() => _success = null)),

            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Notifications'),
                      if (_unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$_unreadCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Announcements'),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildNotificationsTab(),
                        _buildAnnouncementsTab(canAnnounce),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notifications Tab ───────────────────────────────────────────────────────

  Widget _buildNotificationsTab() {
    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // Read filter
              DropdownButton<bool?>(
                value: _notifReadFilter,
                hint: const Text('All'),
                items: const [
                  DropdownMenuItem<bool?>(value: null, child: Text('All')),
                  DropdownMenuItem<bool?>(value: false, child: Text('Unread')),
                  DropdownMenuItem<bool?>(value: true, child: Text('Read')),
                ],
                onChanged: (v) {
                  setState(() => _notifReadFilter = v);
                  _loadNotifications();
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Refresh'),
                onPressed: _loadNotifications,
              ),
              const Spacer(),
              if (_unreadCount > 0)
                TextButton.icon(
                  icon: const Icon(Icons.done_all, size: 14),
                  label: const Text('Mark All Read'),
                  onPressed: _markAllRead,
                ),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                label: const Text('Clear Read'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _clearRead,
              ),
            ],
          ),
        ),
        // List
        if (_notifications.isEmpty)
          const Expanded(
              child: Center(child: Text('No notifications found.')))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = _notifications[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        n.isRead ? Colors.grey.shade200 : Colors.blue.shade100,
                    child: Icon(
                      _notifIcon(n.type),
                      size: 16,
                      color: n.isRead ? Colors.grey : Colors.blue,
                    ),
                  ),
                  title: Text(n.title,
                      style: TextStyle(
                          fontWeight: n.isRead
                              ? FontWeight.w400
                              : FontWeight.w700)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                      Text(
                        _formatDate(n.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: n.isRead
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle)),
                  onTap: n.isRead
                      ? null
                      : () async {
                          await _repo.markRead([n.id]);
                          _loadNotifications();
                        },
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _notifIcon(String type) {
    switch (type.toUpperCase()) {
      case 'ATTENDANCE':
        return Icons.today_outlined;
      case 'FEE':
        return Icons.payments_outlined;
      case 'APPROVAL':
        return Icons.verified_user_outlined;
      case 'ANNOUNCEMENT':
        return Icons.campaign_outlined;
      case 'RESULT':
        return Icons.analytics_outlined;
      case 'DOCUMENT':
        return Icons.folder_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  // ── Announcements Tab ───────────────────────────────────────────────────────

  Widget _buildAnnouncementsTab(bool canCreate) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text('${_announcements.length} announcement(s)',
                  style: const TextStyle(color: Colors.grey)),
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
        if (_announcements.isEmpty)
          const Expanded(
              child: Center(child: Text('No announcements found.')))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _announcements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = _announcements[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        a.typeColor.withOpacity(0.15),
                    child: Icon(Icons.campaign_outlined,
                        size: 16, color: a.typeColor),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                          child: Text(a.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: a.typeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(a.type,
                            style: TextStyle(
                                color: a.typeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (!a.isActive) ...[
                        const SizedBox(width: 4),
                        const Chip(
                            label: Text('Inactive',
                                style: TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                      if (a.targetRole != null)
                        Text('Target: ${a.targetRole}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.blue)),
                      Text(_formatDate(a.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  trailing: canCreate
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () =>
                              _showCreateAnnouncementDialog(existing: a),
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

// ── Shared banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner(
      {required this.message,
      required this.isError,
      required this.onDismiss});
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
              child: Text(message,
                  style: TextStyle(color: color.shade700, fontSize: 13))),
          GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 14, color: color.shade400)),
        ],
      ),
    );
  }
}