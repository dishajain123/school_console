// lib/presentation/dashboard/screens/dashboard_screen.dart  [Admin Console]
// Landing canvas: signed-in context and navigation hint (sidebar is primary nav).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.valueOrNull;
    final theme = Theme.of(context);

    final subtitle = user == null
        ? 'Loading your session…'
        : [
            'Role: ${user.role}',
            if (user.email != null && user.email!.trim().isNotEmpty)
              user.email!.trim(),
            if (user.phone != null && user.phone!.trim().isNotEmpty)
              user.phone!.trim(),
          ].join(' · ');

    return AdminScaffold(
      title: 'Dashboard',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminPageHeader(
              title: 'Welcome',
              subtitle: subtitle,
            ),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AdminColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin console',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.sm),
                    Text(
                      'Use the left sidebar to open approvals, enrollment, '
                      'academics, fees, results, and other modules. Your visible '
                      'items depend on your role and permissions.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AdminColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
