import 'package:flutter/material.dart';

import '../../../../core/theme/admin_colors.dart';
import 'admin_spacing.dart';

/// Skeleton-style loading block (no data logic). Replaces a lone spinner.
class AdminLoadingPlaceholder extends StatefulWidget {
  const AdminLoadingPlaceholder({
    super.key,
    this.message = 'Loading…',
    this.height = 280,
  });

  final String message;
  final double height;

  @override
  State<AdminLoadingPlaceholder> createState() =>
      _AdminLoadingPlaceholderState();
}

class _AdminLoadingPlaceholderState extends State<AdminLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.45, end: 0.9).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SkeletonBar(width: 0.42, height: 12),
                    const SizedBox(height: AdminSpacing.md),
                    _SkeletonBar(width: 0.72, height: 10),
                    const SizedBox(height: AdminSpacing.sm),
                    _SkeletonBar(width: 0.88, height: 10),
                    const SizedBox(height: AdminSpacing.sm),
                    _SkeletonBar(width: 0.55, height: 10),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AdminColors.primaryAction.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Text(
                    widget.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});

  /// Fraction of parent width (0–1).
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth * width).clamp(48.0, constraints.maxWidth);
        return Container(
          width: w,
          height: height,
          decoration: BoxDecoration(
            color: AdminColors.borderSubtle,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}
