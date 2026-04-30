//Users/dishajain/Desktop/admin_console/lib/presentation/approvals/screens/approval_queue_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/registration/approval_action.dart';
import '../../../data/models/registration/registration_request.dart';
import '../../../domains/providers/approval_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../widgets/approval_table.dart';

class ApprovalQueueScreen extends ConsumerStatefulWidget {
  const ApprovalQueueScreen({super.key});

  @override
  ConsumerState<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends ConsumerState<ApprovalQueueScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _status;
  String? _role;
  String? _source;
  final Set<String> _selectedUserIds = <String>{};
  bool _bulkLoading = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.invalidate(approvalQueueFilteredProvider(_query));
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  ({String? status, String? role, String? source, String? q}) get _query => (
        status: _status,
        role: _role,
        source: _source,
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );

  Future<void> _runBulkAction(
    List<RegistrationRequest> items,
    ApprovalActionType action,
  ) async {
    if (_selectedUserIds.isEmpty || _bulkLoading) return;
    final selectedItems = items
        .where((item) => _selectedUserIds.contains(item.userId))
        .toList();
    if (selectedItems.isEmpty) return;

    String? note;
    if (action == ApprovalActionType.reject || action == ApprovalActionType.hold) {
      final noteCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == ApprovalActionType.reject
                ? 'Reject selected users'
                : 'Put selected users on hold',
          ),
          content: TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve selected users'),
          content: Text('Approve ${selectedItems.length} selected users?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _bulkLoading = true);
    var success = 0;
    var failed = 0;
    final repo = ref.read(approvalRepositoryProvider);
    for (final item in selectedItems) {
      try {
        await repo.decide(
          userId: item.userId,
          action: action,
          note: note,
          overrideValidation: false,
        );
        success++;
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(approvalQueueFilteredProvider(_query));
    if (!mounted) return;
    setState(() {
      _bulkLoading = false;
      _selectedUserIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Bulk action completed for $success users.'
              : 'Bulk action done: $success success, $failed failed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(approvalQueueFilteredProvider(_query));

    return AdminScaffold(
      title: 'Approval Queue',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search name/email/phone',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _status,
                  hint: const Text('Status'),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('All')),
                    DropdownMenuItem<String?>(
                        value: 'PENDING_APPROVAL', child: Text('Pending')),
                    DropdownMenuItem<String?>(
                        value: 'ACTIVE', child: Text('Approved')),
                    DropdownMenuItem<String?>(value: 'ON_HOLD', child: Text('On Hold')),
                    DropdownMenuItem<String?>(value: 'REJECTED', child: Text('Rejected')),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _role,
                  hint: const Text('Role'),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('All')),
                    DropdownMenuItem<String?>(value: 'STUDENT', child: Text('Student')),
                    DropdownMenuItem<String?>(value: 'PARENT', child: Text('Parent')),
                    DropdownMenuItem<String?>(value: 'TEACHER', child: Text('Teacher')),
                    DropdownMenuItem<String?>(value: 'PRINCIPAL', child: Text('Principal')),
                    DropdownMenuItem<String?>(value: 'TRUSTEE', child: Text('Trustee')),
                  ],
                  onChanged: (v) => setState(() => _role = v),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Apply filters',
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.filter_alt),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(approvalQueueFilteredProvider(_query)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: queue.when(
                data: (items) {
                  final selectableItems = items
                      .where((e) =>
                          e.status == 'PENDING_APPROVAL' ||
                          e.status == 'ON_HOLD')
                      .toList();
                  return Column(
                    children: [
                      Row(
                        children: [
                          Text('Selected: ${_selectedUserIds.length}'),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: (_selectedUserIds.isEmpty || _bulkLoading)
                                ? null
                                : () => _runBulkAction(
                                      selectableItems,
                                      ApprovalActionType.approve,
                                    ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Approve Selected'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: (_selectedUserIds.isEmpty || _bulkLoading)
                                ? null
                                : () => _runBulkAction(
                                      selectableItems,
                                      ApprovalActionType.reject,
                                    ),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Reject Selected'),
                          ),
                          const SizedBox(width: 8),
                          if (_bulkLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ApprovalTable(
                          items: items,
                          selectedUserIds: _selectedUserIds,
                          onToggleSelect: (userId, selected) {
                            setState(() {
                              if (selected) {
                                _selectedUserIds.add(userId);
                              } else {
                                _selectedUserIds.remove(userId);
                              }
                            });
                          },
                          onToggleSelectAll: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedUserIds
                                  ..clear()
                                  ..addAll(
                                    selectableItems.map((e) => e.userId),
                                  );
                              } else {
                                _selectedUserIds.clear();
                              }
                            });
                          },
                          onOpen: (item) => context.go('/approvals/${item.userId}'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
