import 'package:flutter/material.dart';

import 'admin_spacing.dart';

/// Main content block — white card on grey canvas.
class AdminSurfaceCard extends StatelessWidget {
  const AdminSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AdminSpacing.md),
    this.clipScroll = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool clipScroll;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(padding: padding, child: child);
    return Card(
      clipBehavior: clipScroll ? Clip.antiAlias : Clip.none,
      child: inner,
    );
  }
}
