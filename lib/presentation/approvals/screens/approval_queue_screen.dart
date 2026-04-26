import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domains/providers/approval_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../widgets/approval_table.dart';

class ApprovalQueueScreen extends ConsumerWidget {
  const ApprovalQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(approvalQueueProvider);

    return AdminScaffold(
      title: 'Approval Queue',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: queue.when(
          data: (items) => ApprovalTable(
            items: items,
            onOpen: (item) => context.go('/approvals/${item.userId}'),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
        ),
      ),
    );
  }
}
