// lib/presentation/common/layout/sidebar.dart  [Admin Console]
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_constants.dart';
import '../../../data/models/auth/admin_user.dart';
import '../../../domains/providers/auth_provider.dart';

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}

// Full ordered list of all navigation items
const _allItems = [
  _NavItem(
    icon: Icons.verified_user_outlined,
    selectedIcon: Icons.verified_user,
    label: 'Approvals',
    route: RouteNames.approvals,
  ),
  _NavItem(
    icon: Icons.history_toggle_off,
    selectedIcon: Icons.history,
    label: 'Audit Log',
    route: RouteNames.audit,
  ),
  _NavItem(
    icon: Icons.account_tree_outlined,
    selectedIcon: Icons.account_tree,
    label: 'Acad. Years',
    route: RouteNames.academics,
  ),
  _NavItem(
    icon: Icons.class_outlined,
    selectedIcon: Icons.class_,
    label: 'Classes',
    route: RouteNames.academicStructure,
  ),
  _NavItem(
    icon: Icons.how_to_reg_outlined,
    selectedIcon: Icons.how_to_reg,
    label: 'Enrollment',
    route: RouteNames.enrollment,
  ),
  _NavItem(
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    label: 'Profiles',
    route: RouteNames.roleProfiles,
  ),
  _NavItem(
    icon: Icons.numbers_outlined,
    selectedIcon: Icons.numbers,
    label: 'ID Config',
    route: RouteNames.identifierConfigs,
  ),
  _NavItem(
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: 'Users',
    route: RouteNames.users,
  ),
  _NavItem(
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments,
    label: 'Fees',
    route: RouteNames.fees,
  ),
  _NavItem(
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    label: 'Reports',
    route: RouteNames.reports,
  ),
  _NavItem(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Settings',
    route: RouteNames.settings,
  ),
];

/// Returns the navigation items visible to [user] based on role and permissions.
/// Phase 5 requirement: each admin role only accesses permitted modules.
List<_NavItem> _itemsForUser(AdminUser user) {
  final role = user.role.toUpperCase();
  final perms = user.permissions;

  // SUPERADMIN sees everything
  if (role == 'SUPERADMIN') return _allItems;

  final visible = <_NavItem>[];

  // Approval-related (PRINCIPAL / STAFF with review permission)
  if (role == 'PRINCIPAL' || user.canReview) {
    visible.addAll([
      _allItems[0], // Approvals
      _allItems[1], // Audit Log
    ]);
  }

  // Academic structure (PRINCIPAL and staff with settings:manage)
  if (role == 'PRINCIPAL' || perms.contains('settings:manage')) {
    visible.addAll([
      _allItems[2], // Acad. Years
      _allItems[3], // Classes/Sections
    ]);
  }

  // Enrollment (PRINCIPAL and staff with user:manage)
  if (role == 'PRINCIPAL' || perms.contains('user:manage')) {
    visible.add(_allItems[4]); // Enrollment
  }

  // Role Profiles & ID config (user:manage permission)
  if (role == 'PRINCIPAL' || perms.contains('user:manage')) {
    visible.add(_allItems[5]); // Role Profiles
    visible.add(_allItems[6]); // ID Config
  }

  // Users management (user:manage permission)
  if (role == 'PRINCIPAL' || perms.contains('user:manage')) {
    visible.add(_allItems[7]); // Users
  }

  // Fees (fee:read or fee:create permission)
  if (perms.contains('fee:read') || perms.contains('fee:create')) {
    visible.add(_allItems[8]); // Fees
  }

  // Reports (PRINCIPAL can see reports)
  if (role == 'PRINCIPAL') {
    visible.add(_allItems[9]); // Reports
  }

  // Settings (PRINCIPAL manages school settings)
  if (role == 'PRINCIPAL' || perms.contains('settings:manage')) {
    visible.add(_allItems[10]); // Settings
  }

  // Remove duplicates while preserving insertion order
  final seen = <String>{};
  return visible.where((item) => seen.add(item.route)).toList();
}

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final user = ref.watch(authControllerProvider).valueOrNull;

    if (user == null) return const SizedBox.shrink();

    final items = _itemsForUser(user);

    // Determine which item is selected
    int selectedIndex = 0;
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route)) {
        selectedIndex = i;
        break;
      }
    }

    return NavigationRail(
      selectedIndex: selectedIndex.clamp(0, items.length - 1),
      onDestinationSelected: (index) {
        context.go(items[index].route);
      },
      labelType: NavigationRailLabelType.all,
      destinations: items
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: Text(item.label),
            ),
          )
          .toList(),
    );
  }
}