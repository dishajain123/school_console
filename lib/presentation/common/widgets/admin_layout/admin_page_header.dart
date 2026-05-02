import 'package:flutter/material.dart';

import '../../../../core/theme/admin_colors.dart';
import 'admin_spacing.dart';

/// Page chrome: title + optional subtitle + primary action + icon actions (right).
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.primaryAction,
    this.iconActions = const [],
  });

  final String title;
  final String? subtitle;
  /// Primary CTA (e.g. FilledButton) — placed on the right before icon actions.
  final Widget? primaryAction;
  final List<Widget> iconActions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textPrimary,
                      ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: AdminSpacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: AdminColors.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (primaryAction != null) ...[
            const SizedBox(width: AdminSpacing.md),
            primaryAction!,
          ],
          ...iconActions.map(
            (w) => Padding(
              padding: const EdgeInsets.only(left: AdminSpacing.xs),
              child: IconTheme(
                data: const IconThemeData(
                  color: AdminColors.textSecondary,
                  size: 22,
                ),
                child: w,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
