import 'package:flutter/material.dart';

import 'sidebar.dart';
import 'top_bar.dart';

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopBar(title: title),
      body: Row(
        children: [
          const AdminSidebar(),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
