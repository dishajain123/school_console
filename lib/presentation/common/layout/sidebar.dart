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

// Full ordered list — indices referenced by _itemsForUser() below.
const _allItems = [
  // 0 — Approvals
  _NavItem(icon: Icons.verified_user_outlined, selectedIcon: Icons.verified_user, label: 'Approvals', route: RouteNames.approvals),
  // 1 — Audit Log
  _NavItem(icon: Icons.history_toggle_off, selectedIcon: Icons.history, label: 'Audit Log', route: RouteNames.audit),
  // 2 — Academic Years
  _NavItem(icon: Icons.account_tree_outlined, selectedIcon: Icons.account_tree, label: 'Acad. Years', route: RouteNames.academics),
  // 3 — Classes/Sections
  _NavItem(icon: Icons.class_outlined, selectedIcon: Icons.class_, label: 'Classes', route: RouteNames.academicStructure),
  // 4 — Enrollment
  _NavItem(icon: Icons.how_to_reg_outlined, selectedIcon: Icons.how_to_reg, label: 'Enrollment', route: RouteNames.enrollment),
  // 5 — Promotion (Phase 7)
  _NavItem(icon: Icons.trending_up_outlined, selectedIcon: Icons.trending_up, label: 'Promotion', route: RouteNames.promotion),
  // 6 — Teacher Assignments (Phase 4) — assign teacher → subject → class → section
  _NavItem(icon: Icons.assignment_ind_outlined, selectedIcon: Icons.assignment_ind, label: 'Teacher Assign.', route: RouteNames.teacherAssignments),
  // 7 — Role Profiles
  _NavItem(icon: Icons.badge_outlined, selectedIcon: Icons.badge, label: 'Profiles', route: RouteNames.roleProfiles),
  // 8 — ID Config
  _NavItem(icon: Icons.numbers_outlined, selectedIcon: Icons.numbers, label: 'ID Config', route: RouteNames.identifierConfigs),
  // 9 — Users
  _NavItem(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Users', route: RouteNames.users),
  // 10 — Fees (Phase 8)
  _NavItem(icon: Icons.payments_outlined, selectedIcon: Icons.payments, label: 'Fees', route: RouteNames.fees),
  // 11 — Attendance Monitor (Phase 9)
  _NavItem(icon: Icons.today_outlined, selectedIcon: Icons.today, label: 'Attendance', route: RouteNames.attendanceMonitor),
  // 12 — Exams & Results (Phase 10)
  _NavItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics, label: 'Results', route: RouteNames.examsResults),
  // 13 — Reports & Analytics (Phase 11)
  _NavItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Reports', route: RouteNames.reports),
  // 14 — Communication (Phase 12)
  _NavItem(icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: 'Communication', route: RouteNames.communication),
  // 15 — Documents (Phase 13)
  _NavItem(icon: Icons.folder_outlined, selectedIcon: Icons.folder, label: 'Documents', route: RouteNames.documents),
  // 16 — Settings
  _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings', route: RouteNames.settings),
];

/// Returns the navigation items visible to [user] based on role and permissions.
List<_NavItem> _itemsForUser(AdminUser user) {
  final role = user.role.toUpperCase();
  final perms = user.permissions;

  // SUPERADMIN sees everything
  if (role == 'SUPERADMIN') return _allItems;

  // TRUSTEE: read-only — Reports, Fees view, Attendance view, Results view
  if (role == 'TRUSTEE') {
    return [
      _allItems[13], // Reports
      _allItems[10], // Fees (read-only)
      _allItems[11], // Attendance
      _allItems[12], // Results
    ];
  }

  final visible = <_NavItem>[];

  // Approvals & Audit — PRINCIPAL or staff with approval:review
  if (role == 'PRINCIPAL' || user.canReview) {
    visible.add(_allItems[0]);
    visible.add(_allItems[1]);
  }

  // Academic structure — PRINCIPAL or settings:manage
  if (role == 'PRINCIPAL' || perms.contains('settings:manage')) {
    visible.add(_allItems[2]);
    visible.add(_allItems[3]);
  }

  // Enrollment — PRINCIPAL or user:manage
  if (role == 'PRINCIPAL' || perms.contains('user:manage')) {
    visible.add(_allItems[4]);
  }

  // Promotion (Phase 7) — PRINCIPAL or student:promote
  if (role == 'PRINCIPAL' || perms.contains('student:promote')) {
    visible.add(_allItems[5]);
  }

  // Teacher Assignments — PRINCIPAL or teacher_assignment:manage
  if (role == 'PRINCIPAL' || perms.contains('teacher_assignment:manage')) {
    visible.add(_allItems[6]);
  }

  // Role Profiles & ID Config — user:manage
  if (role == 'PRINCIPAL' || perms.contains('user:manage')) {
    visible.add(_allItems[7]);
    visible.add(_allItems[8]);
  }

  // Users — user:manage
  if (role == 'PRINCIPAL' || perms.contains('user:manage')) {
    visible.add(_allItems[9]);
  }

  // Fees — fee:read or fee:create (accounts staff)
  if (perms.contains('fee:read') || perms.contains('fee:create')) {
    visible.add(_allItems[10]);
  }

  // Attendance Monitor (Phase 9) — PRINCIPAL or attendance:read
  if (role == 'PRINCIPAL' || perms.contains('attendance:read')) {
    visible.add(_allItems[11]);
  }

  // Exams & Results (Phase 10) — PRINCIPAL or result:publish/result:create
  if (role == 'PRINCIPAL' ||
      perms.contains('result:publish') ||
      perms.contains('result:create')) {
    visible.add(_allItems[12]);
  }

  // Reports (Phase 11) — PRINCIPAL
  if (role == 'PRINCIPAL') {
    visible.add(_allItems[13]);
  }

  // Communication (Phase 12) — PRINCIPAL or announcement:create
  if (role == 'PRINCIPAL' || perms.contains('announcement:create')) {
    visible.add(_allItems[14]);
  }

  // Documents (Phase 13) — PRINCIPAL or document:manage
  if (role == 'PRINCIPAL' ||
      perms.contains('document:manage') ||
      perms.contains('document:generate')) {
    visible.add(_allItems[15]);
  }

  // Settings — PRINCIPAL or settings:manage
  if (role == 'PRINCIPAL' || perms.contains('settings:manage')) {
    visible.add(_allItems[16]);
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

    // Longest-prefix match for selection
    int selectedIndex = 0;
    int longestMatch = 0;
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route) &&
          items[i].route.length > longestMatch) {
        selectedIndex = i;
        longestMatch = items[i].route.length;
      }
    }

    return NavigationRail(
      selectedIndex: selectedIndex.clamp(0, items.length - 1),
      onDestinationSelected: (index) => context.go(items[index].route),
      labelType: NavigationRailLabelType.all,
      destinations: items
          .map((item) => NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              ))
          .toList(),
    );
  }
}