import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import 'sidebar.dart';
import 'top_bar.dart';

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
          const VerticalDivider(width: 1, color: AdminColors.border),
          Expanded(
            child: ColoredBox(
              color: AdminColors.canvas,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
