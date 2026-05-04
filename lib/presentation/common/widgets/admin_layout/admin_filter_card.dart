import 'package:flutter/material.dart';

import '../../../../core/theme/admin_colors.dart';
import 'admin_spacing.dart';

/// Filters in a white card — inline fields + optional Reset.
class AdminFilterCard extends StatelessWidget {
  const AdminFilterCard({
    super.key,
    required this.child,
    this.onReset,
    this.resetLabel = 'Reset',
    this.padding,
    this.headerGap = AdminSpacing.sm,
  });

  final Widget child;
  final VoidCallback? onReset;
  final String resetLabel;
  /// Defaults to [AdminSpacing.md] on all sides — use tighter padding to save vertical space.
  final EdgeInsetsGeometry? padding;
  /// Space between the "Filters" row and [child].
  final double headerGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'FILTERS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AdminColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                if (onReset != null)
                  TextButton(
                    onPressed: onReset,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminSpacing.sm,
                        vertical: AdminSpacing.xs,
                      ),
                    ),
                    child: Text(resetLabel),
                  ),
              ],
            ),
            SizedBox(height: headerGap),
            child,
          ],
        ),
      ),
    );
  }
}
