import 'package:flutter/material.dart';

import '../../../../core/theme/admin_colors.dart';
import 'admin_spacing.dart';

/// Lightweight loading state inside a card (no logic).
class AdminLoadingPlaceholder extends StatelessWidget {
  const AdminLoadingPlaceholder({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AdminColors.primaryAction,
                ),
              ),
              const SizedBox(height: AdminSpacing.md),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AdminColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
