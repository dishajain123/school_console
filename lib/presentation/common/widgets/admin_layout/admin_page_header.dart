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
  /// Primary CTA (e.g. [FilledButton]) — placed on the right before icon actions.
  final Widget? primaryAction;
  final List<Widget> iconActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AdminColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: AdminSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AdminColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (primaryAction != null) ...[
            const SizedBox(width: AdminSpacing.md),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: primaryAction!,
            ),
          ],
          ...iconActions.map(
            (w) => Padding(
              padding: const EdgeInsets.only(left: AdminSpacing.xs, top: 2),
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
