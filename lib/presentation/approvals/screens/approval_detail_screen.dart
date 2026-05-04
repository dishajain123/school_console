//Users/dishajain/Desktop/admin_console/lib/presentation/approvals/screens/approval_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/providers/approval_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
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
      title: 'Approval detail',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: detail.when(
          data: (item) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: item.fullName ?? 'Registration',
                subtitle: [
                  if ((item.email ?? '').trim().isNotEmpty) item.email!,
                  if ((item.phone ?? '').trim().isNotEmpty) item.phone!,
                  item.role,
                ].where((s) => s.trim().isNotEmpty).join(' · '),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    UserDetailCard(item: item),
                    const SizedBox(height: AdminSpacing.md),
                    DecisionPanel(
                      userId: userId,
                      canDecide: auth?.canDecide ?? false,
                      isSuperAdmin:
                          (auth?.role.toUpperCase() ?? '') == 'STAFF_ADMIN',
                      currentStatus: item.status,
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const AdminLoadingPlaceholder(
            message: 'Loading registration…',
            height: 240,
          ),
          error: (e, _) => AdminEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load registration',
            message: e.toString(),
            action: FilledButton.icon(
              onPressed: () => ref.invalidate(approvalDetailProvider(userId)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ),
      ),
    );
  }
}
