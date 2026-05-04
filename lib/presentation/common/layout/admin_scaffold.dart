import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import 'sidebar.dart';
import 'top_bar.dart';

/// Shell: top app bar + sidebar + main canvas. No routing or data logic.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.canvas,
      appBar: TopBar(title: title),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSidebar(),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: AdminColors.sidebarDivider,
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AdminColors.canvas,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
