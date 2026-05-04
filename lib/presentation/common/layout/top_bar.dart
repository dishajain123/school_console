import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_constants.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/auth_provider.dart';

class TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label =
        title.trim().isEmpty ? 'Admin Console' : title.trim();

    return AppBar(
      // Bottom hairline comes from [buildAdminTheme] appBarTheme.shape.
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.appBarTheme.titleTextStyle,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go(RouteNames.login);
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            style: IconButton.styleFrom(
              foregroundColor: AdminColors.textSecondary,
              highlightColor:
                  AdminColors.primaryAction.withValues(alpha: 0.12),
            ),
          ),
        ),
      ],
    );
  }
}
