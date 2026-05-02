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
    final label =
        title.trim().isEmpty ? 'Admin Console' : title.trim();
    return AppBar(
      title: Text(
        label,
        style: Theme.of(context).appBarTheme.titleTextStyle,
      ),
      shape: const Border(
        bottom: BorderSide(color: AdminColors.border, width: 1),
      ),
      actions: [
        IconButton(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).logout();
            if (context.mounted) context.go(RouteNames.login);
          },
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Sign out',
          style: IconButton.styleFrom(
            foregroundColor: AdminColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
