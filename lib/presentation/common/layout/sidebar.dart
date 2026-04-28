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
  // 4 — Enrollment (roster view)
  _NavItem(icon: Icons.how_to_reg_outlined, selectedIcon: Icons.how_to_reg, label: 'Enrollment', route: RouteNames.enrollment),
  // 5 — Student Lifecycle (Phase 14/15) — unified transfer/exit/re-enroll
  _NavItem(icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts, label: 'Lifecycle', route: RouteNames.lifecycleManagement),
  // 6 — Promotion (Phase 7)
  _NavItem(icon: Icons.trending_up_outlined, selectedIcon: Icons.trending_up, label: 'Promotion', route: RouteNames.promotion),
  // 7 — Teacher Assignments (Phase 4)
  _NavItem(icon: Icons.assignment_ind_outlined, selectedIcon: Icons.assignment_ind, label: 'Teacher Assign.', route: RouteNames.teacherAssignments),
  // 8 — Role Profiles
  _NavItem(icon: Icons.badge_outlined, selectedIcon: Icons.badge, label: 'Profiles', route: RouteNames.roleProfiles),
  // 9 — ID Config
  _NavItem(icon: Icons.numbers_outlined, selectedIcon: Icons.numbers, label: 'ID Config', route: RouteNames.identifierConfigs),
  // 10 — Users
  _NavItem(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Users', route: RouteNames.users),
  // 11 — Fees (Phase 8)
  _NavItem(icon: Icons.payments_outlined, selectedIcon: Icons.payments, label: 'Fees', route: RouteNames.fees),
  // 12 — Attendance Monitor (Phase 9)
  _NavItem(icon: Icons.today_outlined, selectedIcon: Icons.today, label: 'Attendance', route: RouteNames.attendanceMonitor),
  // 13 — Exams & Results (Phase 10)
  _NavItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics, label: 'Results', route: RouteNames.examsResults),
  // 14 — Reports & Analytics (Phase 11)
  _NavItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Reports', route: RouteNames.reports),
  // 15 — Communication (Phase 12)
  _NavItem(icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: 'Communication', route: RouteNames.communication),
  // 16 — Documents (Phase 13)
  _NavItem(icon: Icons.folder_outlined, selectedIcon: Icons.folder, label: 'Documents', route: RouteNames.documents),
  // 17 — Settings
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
      _allItems[14], // Reports
      _allItems[11], // Fees (read-only)
      _allItems[12], // Attendance
      _allItems[13], // Results
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

  // Enrollment & Lifecycle — PRINCIPAL or user:manage
  if (role == 'PRINCIPAL' || perms.contains('user:manage')) {
    visible.add(_allItems[4]);  // Enrollment roster
    visible.add(_allItems[5]);  // Lifecycle management (Phase 14/15)
  }

  // Promotion (Phase 7) — PRINCIPAL or student:promote
  if (role == 'PRINCIPAL' || perms.contains('student:promote')) {
    visible.add(_allItems[6]);
  }

  // Teacher Assignments — PRINCIPAL or teacher_assignment:manage
  if (role == 'PRINCIPAL' || perms.contains('teacher_assignment:manage')) {
    visible.add(_allItems[7]);
  }

  // Role Profiles & ID Config — PRINCIPAL or settings:manage
  if (role == 'PRINCIPAL' || perms.contains('settings:manage')) {
    visible.add(_allItems[8]);
    visible.add(_allItems[9]);
  }

  // Users — PRINCIPAL or user:manage
  if (role == 'PRINCIPAL' || perms.contains('user:manage')) {
    visible.add(_allItems[10]);
  }

  // Fees — fee:read or PRINCIPAL
  if (role == 'PRINCIPAL' || perms.contains('fee:read') || perms.contains('fee:create')) {
    visible.add(_allItems[11]);
  }

  // Attendance monitor — PRINCIPAL or attendance:read
  if (role == 'PRINCIPAL' || perms.contains('attendance:read')) {
    visible.add(_allItems[12]);
  }

  // Results — PRINCIPAL or result:read
  if (role == 'PRINCIPAL' || perms.contains('result:read')) {
    visible.add(_allItems[13]);
  }

  // Reports — PRINCIPAL or reports:read
  if (role == 'PRINCIPAL' || perms.contains('reports:read')) {
    visible.add(_allItems[14]);
  }

  // Communication — PRINCIPAL or announcement:create
  if (role == 'PRINCIPAL' || perms.contains('announcement:create')) {
    visible.add(_allItems[15]);
  }

  // Documents — PRINCIPAL or document:manage
  if (role == 'PRINCIPAL' || perms.contains('document:manage')) {
    visible.add(_allItems[16]);
  }

  // Settings always visible
  visible.add(_allItems[17]);

  return visible;
}

// ── Sidebar widget ────────────────────────────────────────────────────────────

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final items = _itemsForUser(user);
    final location = GoRouterState.of(context).matchedLocation;

    return NavigationDrawer(
      selectedIndex: items.indexWhere(
        (item) => location.startsWith(item.route),
      ),
      onDestinationSelected: (i) {
        context.go(items[i].route);
        if (Scaffold.of(context).isDrawerOpen) {
          Navigator.of(context).pop();
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Admin Console',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(),
        ...items.map(
          (item) => NavigationDrawerDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign Out'),
          onTap: () {
            ref.read(authControllerProvider.notifier).logout();
          },
        ),
      ],
    );
  }
}