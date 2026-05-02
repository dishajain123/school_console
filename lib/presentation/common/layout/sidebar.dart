// lib/presentation/common/layout/sidebar.dart  [Admin Console]
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_constants.dart';
import '../../../core/theme/admin_colors.dart';
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
  // 1 — Enrollment (roster view)
  _NavItem(icon: Icons.how_to_reg_outlined, selectedIcon: Icons.how_to_reg, label: 'Enrollment', route: RouteNames.enrollment),
  // 2 — Student Lifecycle (Phase 14/15) — unified transfer/exit/re-enroll
  _NavItem(icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts, label: 'Lifecycle', route: RouteNames.lifecycleManagement),
  // 3 — Teacher Assignments (Phase 4)
  _NavItem(icon: Icons.assignment_ind_outlined, selectedIcon: Icons.assignment_ind, label: 'Teacher Assign.', route: RouteNames.teacherAssignments),
  // 4 — Promotion (Phase 7)
  _NavItem(icon: Icons.trending_up_outlined, selectedIcon: Icons.trending_up, label: 'Promotion', route: RouteNames.promotion),
  // 5 — Classes/Sections
  _NavItem(icon: Icons.class_outlined, selectedIcon: Icons.class_, label: 'Classes', route: RouteNames.academicStructure),
  // 6 — Academic Years
  _NavItem(icon: Icons.account_tree_outlined, selectedIcon: Icons.account_tree, label: 'Acad. Years', route: RouteNames.academics),
  // 7 — Role Profiles
  _NavItem(icon: Icons.badge_outlined, selectedIcon: Icons.badge, label: 'Profiles', route: RouteNames.roleProfiles),
  // 8 — Fees (Phase 8)
  _NavItem(icon: Icons.payments_outlined, selectedIcon: Icons.payments, label: 'Fees', route: RouteNames.fees),
  // 9 — Exams & Results (Phase 10)
  _NavItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics, label: 'Results', route: RouteNames.examsResults),
  // 10 — Reports & Analytics (Phase 11)
  _NavItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Reports', route: RouteNames.reports),
  // 11 — Audit Log
  _NavItem(icon: Icons.history_toggle_off, selectedIcon: Icons.history, label: 'Audit Log', route: RouteNames.audit),
  // 12 — Communication (Phase 12)
  _NavItem(icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: 'Communication', route: RouteNames.communication),
  // 13 — Documents (Phase 13)
  _NavItem(icon: Icons.folder_outlined, selectedIcon: Icons.folder, label: 'Documents', route: RouteNames.documents),
  // 14 — Settings
  _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings', route: RouteNames.settings),
];

/// Returns the navigation items visible to [user] based on role and permissions.
List<_NavItem> _itemsForUser(AdminUser user) {
  final role = user.role.toUpperCase();
  final perms = user.permissions;
  final byRoute = {for (final item in _allItems) item.route: item};
  void addRoute(List<_NavItem> list, String route) {
    final item = byRoute[route];
    if (item != null) list.add(item);
  }

  // SUPERADMIN sees everything
  if (role == 'SUPERADMIN') return _allItems;

  // TRUSTEE: read-only — Reports, Fees view, Results view
  if (role == 'TRUSTEE') {
    return [
      byRoute[RouteNames.reports]!,
      byRoute[RouteNames.fees]!,
      byRoute[RouteNames.examsResults]!,
    ];
  }

  final visible = <_NavItem>[];

  // Approvals
  if (role == 'PRINCIPAL' || user.canReview) {
    addRoute(visible, RouteNames.approvals);
  }

  // Enrollment & Lifecycle — PRINCIPAL or user:manage
  if (role == 'PRINCIPAL' || perms.contains('user:manage')) {
    addRoute(visible, RouteNames.enrollment); // Enrollment roster
    addRoute(visible, RouteNames.lifecycleManagement); // Lifecycle management
  }

  // Teacher Assignments — PRINCIPAL or teacher_assignment:manage
  if (role == 'PRINCIPAL' || perms.contains('teacher_assignment:manage')) {
    addRoute(visible, RouteNames.teacherAssignments);
  }

  // Promotion — PRINCIPAL or student:promote
  if (role == 'PRINCIPAL' || perms.contains('student:promote')) {
    addRoute(visible, RouteNames.promotion);
  }

  // Classes + Academic Years + Profiles — PRINCIPAL or settings:manage
  if (role == 'PRINCIPAL' || perms.contains('settings:manage')) {
    addRoute(visible, RouteNames.academicStructure);
    addRoute(visible, RouteNames.academics);
    addRoute(visible, RouteNames.roleProfiles);
  }

  // Fees — fee:read or PRINCIPAL
  if (role == 'PRINCIPAL' || perms.contains('fee:read') || perms.contains('fee:create')) {
    addRoute(visible, RouteNames.fees);
  }

  // Results — PRINCIPAL or result:read
  if (role == 'PRINCIPAL' || perms.contains('result:read')) {
    addRoute(visible, RouteNames.examsResults);
  }

  // Reports — PRINCIPAL or reports:read
  if (role == 'PRINCIPAL' || perms.contains('reports:read')) {
    addRoute(visible, RouteNames.reports);
  }

  // Audit Log
  if (role == 'PRINCIPAL' || user.canReview) {
    addRoute(visible, RouteNames.audit);
  }

  // Communication — PRINCIPAL or announcement:create
  if (role == 'PRINCIPAL' || perms.contains('announcement:create')) {
    addRoute(visible, RouteNames.communication);
  }

  // Documents — PRINCIPAL or document:manage
  if (role == 'PRINCIPAL' || perms.contains('document:manage')) {
    addRoute(visible, RouteNames.documents);
  }

  // Settings — only users who can manage settings
  if (role == 'PRINCIPAL' || perms.contains('settings:manage')) {
    addRoute(visible, RouteNames.settings);
  }

  return visible;
}

// ── Sidebar widget ────────────────────────────────────────────────────────────

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key});

  String _normalizePath(String path) {
    if (path.isEmpty) return '/';
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  int _resolveSelectedIndex(List<_NavItem> items, String rawLocation) {
    final location = _normalizePath(rawLocation);

    // Prefer exact route match first.
    final exactIndex = items.indexWhere(
      (item) => location == _normalizePath(item.route),
    );
    if (exactIndex != -1) return exactIndex;

    // Explicit family priority prevents parent routes (e.g. /enrollment)
    // from stealing selection for child routes.
    const orderedRoutePriority = <String>[
      RouteNames.lifecycleManagement,
      RouteNames.promotion,
      RouteNames.academicStructure,
      RouteNames.enrollment,
      RouteNames.academics,
    ];
    for (final route in orderedRoutePriority) {
      final normalized = _normalizePath(route);
      if (location == normalized || location.startsWith('$normalized/')) {
        final idx = items.indexWhere((item) => item.route == route);
        if (idx != -1) return idx;
      }
    }

    // Generic fallback: most specific prefix wins.
    final matches = <int>[];
    for (var i = 0; i < items.length; i++) {
      final route = _normalizePath(items[i].route);
      if (location.startsWith('$route/')) {
        matches.add(i);
      }
    }
    if (matches.isEmpty) return -1;

    matches.sort(
      (a, b) => items[b].route.length.compareTo(items[a].route.length),
    );
    return matches.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final items = _itemsForUser(user);
    final location = _normalizePath(
      GoRouter.of(context).routeInformationProvider.value.uri.path,
    );
    final selectedIndex = _resolveSelectedIndex(items, location);

    const railWidth = 268.0;

    return SizedBox(
      width: railWidth,
      child: Material(
        color: AdminColors.sidebarBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Console',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: AdminColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? user.phone ?? user.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AdminColors.textMuted,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminColors.borderSubtle),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: selected
                          ? AdminColors.primaryAction.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        hoverColor:
                            AdminColors.primaryAction.withValues(alpha: 0.06),
                        onTap: () => context.go(item.route),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected ? item.selectedIcon : item.icon,
                                size: 20,
                                color: selected
                                    ? AdminColors.primaryAction
                                    : AdminColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontSize: 13,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: selected
                                            ? AdminColors.primaryAction
                                            : AdminColors.textPrimary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
