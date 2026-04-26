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
        if (index == 1) context.go(RouteNames.academics);
        if (index == 2) context.go(RouteNames.roleProfiles);
        if (index == 3) context.go(RouteNames.identifierConfigs);
        if (index == 4) context.go(RouteNames.audit);
      },
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.verified_user_outlined),
          selectedIcon: Icon(Icons.verified_user),
          label: Text('Approvals'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.account_tree_outlined),
          selectedIcon: Icon(Icons.account_tree),
          label: Text('Academics'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.badge_outlined),
          selectedIcon: Icon(Icons.badge),
          label: Text('Role Profiles'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.numbers_outlined),
          selectedIcon: Icon(Icons.numbers),
          label: Text('ID Config'),
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
    if (path.startsWith(RouteNames.identifierConfigs)) return 3;
    if (path.startsWith(RouteNames.roleProfiles)) return 2;
    if (path.startsWith(RouteNames.academics)) return 1;
    if (path.startsWith('/audit')) return 4;
    return 0;
  }
}
