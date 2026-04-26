import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_constants.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return NavigationRail(
      selectedIndex: _selectedIndex(location),
      onDestinationSelected: (index) {
        if (index == 0) context.go(RouteNames.approvals);
        if (index == 1) context.go(RouteNames.audit);
      },
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.verified_user_outlined),
          selectedIcon: Icon(Icons.verified_user),
          label: Text('Approvals'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.history_toggle_off),
          selectedIcon: Icon(Icons.history),
          label: Text('Audit Log'),
        ),
      ],
    );
  }

  int _selectedIndex(String path) {
    if (path.startsWith('/audit')) return 1;
    return 0;
  }
}
