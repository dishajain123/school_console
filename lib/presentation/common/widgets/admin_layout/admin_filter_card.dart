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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            padding ?? const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AdminColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                ),
                const Spacer(),
                if (onReset != null)
                  TextButton(
                    onPressed: onReset,
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
