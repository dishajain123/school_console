// lib/presentation/common/layout/sidebar.dart  [Admin Console]
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/brand_constants.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/auth/admin_user.dart';
import '../../../domains/providers/auth_provider.dart';
import '../widgets/admin_layout/admin_spacing.dart';
import '../widgets/school_brand_logo.dart';

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
  // 0 — Dashboard
  _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard', route: RouteNames.dashboard),
  // 1 — Approvals
  _NavItem(icon: Icons.verified_user_outlined, selectedIcon: Icons.verified_user, label: 'Approvals', route: RouteNames.approvals),
  // 2 — Enrollment (roster view)
  _NavItem(icon: Icons.how_to_reg_outlined, selectedIcon: Icons.how_to_reg, label: 'Enrollment', route: RouteNames.enrollment),
  // 3 — Student Lifecycle (Phase 14/15) — unified transfer/exit/re-enroll
  _NavItem(icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts, label: 'Lifecycle', route: RouteNames.lifecycleManagement),
  // 4 — Teacher Assignments (Phase 4)
  _NavItem(icon: Icons.assignment_ind_outlined, selectedIcon: Icons.assignment_ind, label: 'Teacher Assign.', route: RouteNames.teacherAssignments),
  // 5 — Promotion (Phase 7)
  _NavItem(icon: Icons.trending_up_outlined, selectedIcon: Icons.trending_up, label: 'Promotion', route: RouteNames.promotion),
  // 6 — Classes/Sections
  _NavItem(icon: Icons.class_outlined, selectedIcon: Icons.class_, label: 'Classes', route: RouteNames.academicStructure),
  // 7 — Academic Years
  _NavItem(icon: Icons.account_tree_outlined, selectedIcon: Icons.account_tree, label: 'Acad. Years', route: RouteNames.academics),
  // 8 — Role Profiles
  _NavItem(icon: Icons.badge_outlined, selectedIcon: Icons.badge, label: 'Profiles', route: RouteNames.roleProfiles),
  // 9 — Fees (Phase 8)
  _NavItem(icon: Icons.payments_outlined, selectedIcon: Icons.payments, label: 'Fees', route: RouteNames.fees),
  // 10 — Examination (Phase 10)
  _NavItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics, label: 'Examination', route: RouteNames.examination),
  // 11 — Reports & Analytics (Phase 11)
  _NavItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Reports', route: RouteNames.reports),
  // 12 — Communication (Phase 12)
  _NavItem(icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: 'Communication', route: RouteNames.communication),
  // 13 — Documents (Phase 13)
  _NavItem(icon: Icons.folder_outlined, selectedIcon: Icons.folder, label: 'Documents', route: RouteNames.documents),
  // 14 — Audit Log (after Documents, before Settings)
  _NavItem(icon: Icons.history_toggle_off, selectedIcon: Icons.history, label: 'Audit Log', route: RouteNames.audit),
  // 15 — Settings
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

  // Staff Admin (web console) sees full navigation for the school.
  if (role == 'STAFF_ADMIN') return _allItems;

  // TRUSTEE: read-only — Reports, Fees view, Examination view
  if (role == 'TRUSTEE') {
    return [
      byRoute[RouteNames.dashboard]!,
      byRoute[RouteNames.reports]!,
      byRoute[RouteNames.fees]!,
      byRoute[RouteNames.examination]!,
    ];
  }

  final visible = <_NavItem>[];
  addRoute(visible, RouteNames.dashboard);

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

  // Examination — PRINCIPAL or result:read
  if (role == 'PRINCIPAL' || perms.contains('result:read')) {
    addRoute(visible, RouteNames.examination);
  }

  // Reports — PRINCIPAL or reports:read
  if (role == 'PRINCIPAL' || perms.contains('reports:read')) {
    addRoute(visible, RouteNames.reports);
  }

  // Communication — PRINCIPAL or announcement:create
  if (role == 'PRINCIPAL' || perms.contains('announcement:create')) {
    addRoute(visible, RouteNames.communication);
  }

  // Documents — PRINCIPAL or document:manage
  if (role == 'PRINCIPAL' || perms.contains('document:manage')) {
    addRoute(visible, RouteNames.documents);
  }

  // Audit Log — after Documents, before Settings
  if (role == 'PRINCIPAL' || user.canReview) {
    addRoute(visible, RouteNames.audit);
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

    const railWidth = 276.0;

    return SizedBox(
      width: railWidth,
      child: Material(
        color: AdminColors.sidebarBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.md,
                AdminSpacing.lg,
                AdminSpacing.sm,
                AdminSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SchoolBrandLogo(height: 48, borderRadius: 10),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          BrandConstants.schoolDisplayName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.35,
                                color: AdminColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          BrandConstants.adminConsoleTitle,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AdminColors.primaryAction,
                                    letterSpacing: 0.15,
                                  ),
                        ),
                        const SizedBox(height: AdminSpacing.sm),
                        Text(
                          'Console',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AdminColors.textMuted,
                                    fontSize: 11,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email ?? user.phone ?? user.role,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AdminColors.textSecondary,
                                    fontSize: 11,
                                    height: 1.25,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: AdminColors.sidebarDivider,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AdminSpacing.xs,
                  AdminSpacing.sm,
                  AdminSpacing.xs,
                  AdminSpacing.md,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AdminSpacing.xs),
                    child: _SidebarNavTile(
                      item: item,
                      selected: selected,
                      onTap: () => context.go(item.route),
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

class _SidebarNavTile extends StatelessWidget {
  const _SidebarNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        hoverColor: AdminColors.primaryAction.withValues(alpha: 0.06),
        splashColor: AdminColors.primaryAction.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? AdminColors.primarySubtle.withValues(alpha: 0.85)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AdminColors.primaryAction.withValues(alpha: 0.18)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: selected ? 3 : 0,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AdminColors.primaryAction,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminSpacing.sm,
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
                        const SizedBox(width: AdminSpacing.sm),
                        Expanded(
                          child: Text(
                            item.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              letterSpacing: selected ? -0.1 : 0,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
