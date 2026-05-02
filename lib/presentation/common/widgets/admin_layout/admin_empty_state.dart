import 'package:flutter/material.dart';

import '../../../../core/theme/admin_colors.dart';
import 'admin_spacing.dart';

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AdminColors.textMuted),
            const SizedBox(height: AdminSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AdminColors.textPrimary,
                  ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: AdminSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: AdminColors.textSecondary,
                    ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AdminSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
