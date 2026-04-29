import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/providers/approval_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../widgets/decision_panel.dart';
import '../widgets/user_detail_card.dart';

class ApprovalDetailScreen extends ConsumerWidget {
  const ApprovalDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(approvalDetailProvider(userId));
    final auth = ref.watch(authControllerProvider).valueOrNull;

    return AdminScaffold(
      title: 'Approval Detail',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: detail.when(
          data: (item) => ListView(
            children: [
              UserDetailCard(item: item),
              const SizedBox(height: 16),
              DecisionPanel(
                userId: userId,
                canDecide: auth?.canDecide ?? false,
                isSuperAdmin: (auth?.role.toUpperCase() ?? '') == 'SUPERADMIN',
                currentStatus: item.status,
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
        ),
      ),
    );
  }
}
