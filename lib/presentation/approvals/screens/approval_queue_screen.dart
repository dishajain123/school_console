import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ({String? status, String? role, String? source, String? q}) get _query => (
        status: _status,
        role: _role,
        source: _source,
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );

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
                data: (items) => ApprovalTable(
                  items: items,
                  onOpen: (item) => context.go('/approvals/${item.userId}'),
                ),
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
