import 'package:flutter/material.dart';

import '../../../../core/theme/admin_colors.dart';
import 'admin_spacing.dart';

/// Main content block — white card on grey canvas.
class AdminSurfaceCard extends StatelessWidget {
  const AdminSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AdminSpacing.md),
    this.clipScroll = true,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool clipScroll;
  /// Outer margin when stacking multiple cards vertically.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(padding: padding, child: child);
    return Padding(
      padding: margin,
      child: Card(
        clipBehavior: clipScroll ? Clip.antiAlias : Clip.none,
        shadowColor: AdminColors.textPrimary.withValues(alpha: 0.04),
        child: inner,
      ),
    );
  }
}
