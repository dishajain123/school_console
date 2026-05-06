// lib/presentation/dashboard/screens/dashboard_screen.dart  [Admin Console]
// Connected overview: approvals, academics, exams, audit — refreshable hub.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_constants.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/audit/audit_log.dart';
import '../../../data/models/dashboard/dashboard_overview.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/dashboard_overview_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_surface_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static String _fmtWhen(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.valueOrNull;
    final overviewAsync = ref.watch(dashboardOverviewProvider);

    final subtitle = user == null
        ? 'Loading your session…'
        : [
            user.role,
            if (user.email != null && user.email!.trim().isNotEmpty)
              user.email!.trim(),
          ].join(' · ');

    return AdminScaffold(
      title: 'Dashboard',
      child: user == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AdminSpacing.pagePadding),
              child: overviewAsync.when(
                loading: () => const _DashboardSkeleton(),
                error: (e, _) => _DashboardError(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(dashboardOverviewProvider),
                ),
                data: (data) => _DashboardBody(
                  userLabel: user.email ?? user.role,
                  subtitle: subtitle,
                  data: data,
                  onRefresh: () =>
                      ref.invalidate(dashboardOverviewProvider),
                ),
              ),
            ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.userLabel,
    required this.subtitle,
    required this.data,
    required this.onRefresh,
  });

  final String userLabel;
  final String subtitle;
  final DashboardOverview data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        return SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminPageHeader(
                    title: 'Welcome back',
                    subtitle: subtitle,
                    primaryAction: FilledButton.tonalIcon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ),
                  if (data.partialErrors.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
                      child: _PartialBanner(errors: data.partialErrors),
                    ),
                  _HeroCard(
                    userLabel: userLabel,
                    data: data,
                  ),
                  SizedBox(height: AdminSpacing.lg + AdminSpacing.xs),
                  _SectionHeader(
                    title: 'At a glance',
                    subtitle: 'Key counts for your school right now',
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  _MetricGrid(
                    wide: wide,
                    data: data,
                  ),
                  SizedBox(height: AdminSpacing.lg + AdminSpacing.xs),
                  _SectionHeader(
                    title: 'Shortcuts',
                    subtitle: 'Jump to common tasks',
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  _ShortcutsRow(wide: wide),
                  SizedBox(height: AdminSpacing.lg + AdminSpacing.xs),
                  _SectionHeader(
                    title: 'Recent activity',
                    subtitle: 'Latest audit events',
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  _AuditPanel(logs: data.recentAudit),
                  const SizedBox(height: AdminSpacing.lg),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: AdminColors.primaryAction,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AdminColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.userLabel,
    required this.data,
  });

  final String userLabel;
  final DashboardOverview data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yearLine = data.hasActiveYear
        ? 'Active year · ${data.activeYear!.name}'
        : 'No academic year on file yet';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            AdminColors.primaryAction,
            AdminColors.primaryPressed,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primaryAction.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userLabel,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AdminColors.textOnPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              'What needs attention across your school today.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AdminColors.textOnPrimary.withValues(alpha: 0.9),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
            Wrap(
              spacing: AdminSpacing.sm,
              runSpacing: AdminSpacing.sm,
              children: [
                _HeroChip(
                  icon: data.apiReachable ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  label: data.apiReachable ? 'API reachable' : 'API check failed',
                  positive: data.apiReachable,
                ),
                _HeroChip(
                  icon: Icons.calendar_month_rounded,
                  label: yearLine,
                  positive: data.hasActiveYear,
                ),
                if (data.allYears.isNotEmpty)
                  _HeroChip(
                    icon: Icons.layers_outlined,
                    label: '${data.allYears.length} academic year(s)',
                    positive: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    required this.positive,
  });

  final IconData icon;
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.textOnPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AdminColors.textOnPrimary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: positive
                ? AdminColors.textOnPrimary
                : AdminColors.textOnPrimary.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AdminColors.textOnPrimary.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.wide,
    required this.data,
  });

  final bool wide;
  final DashboardOverview data;

  @override
  Widget build(BuildContext context) {
    final cross = wide ? 4 : 2;
    final metrics = [
      _MetricSpec(
        title: 'Pending approvals',
        value: '${data.pendingApprovals}',
        hint: 'Registration queue',
        icon: Icons.how_to_reg_outlined,
        color: const Color(0xFFEA580C),
        route: RouteNames.approvals,
      ),
      _MetricSpec(
        title: 'On hold',
        value: '${data.onHoldApprovals}',
        hint: 'Needs follow-up',
        icon: Icons.pause_circle_outline_rounded,
        color: const Color(0xFFCA8A04),
        route: RouteNames.approvals,
      ),
      _MetricSpec(
        title: 'Exams (active year)',
        value: '${data.examsConfigured}',
        hint: 'Configured exams',
        icon: Icons.analytics_outlined,
        color: AdminColors.primaryAction,
        route: RouteNames.examination,
      ),
      _MetricSpec(
        title: 'Classes',
        value: '${data.standardsConfigured}',
        hint: 'Standards this year',
        icon: Icons.class_outlined,
        color: const Color(0xFF059669),
        route: RouteNames.academicStructure,
      ),
    ];
    return GridView.count(
      crossAxisCount: cross,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AdminSpacing.md,
      crossAxisSpacing: AdminSpacing.md,
      childAspectRatio: wide ? 1.52 : 1.32,
      children: metrics
          .map((m) => _MetricTile(spec: m))
          .toList(growable: false),
    );
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.title,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;
  final String route;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.spec});

  final _MetricSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminSurfaceCard(
      padding: EdgeInsets.zero,
      clipScroll: true,
      child: InkWell(
        onTap: () => context.go(spec.route),
        hoverColor: AdminColors.rowHover,
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(spec.icon, color: spec.color, size: 22),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: AdminColors.textMuted,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                spec.value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                spec.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AdminColors.textPrimary,
                ),
              ),
              Text(
                spec.hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AdminColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutsRow extends StatelessWidget {
  const _ShortcutsRow({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (label: 'Approvals', icon: Icons.verified_user_outlined, route: RouteNames.approvals),
      (label: 'Documents', icon: Icons.folder_outlined, route: RouteNames.documents),
      (label: 'Enrollment', icon: Icons.how_to_reg_outlined, route: RouteNames.enrollment),
      (label: 'Fees', icon: Icons.payments_outlined, route: RouteNames.fees),
      (label: 'Examination', icon: Icons.analytics_outlined, route: RouteNames.examination),
      (label: 'Reports', icon: Icons.bar_chart_outlined, route: RouteNames.reports),
      (label: 'Communication', icon: Icons.campaign_outlined, route: RouteNames.communication),
      (label: 'Audit log', icon: Icons.history_rounded, route: RouteNames.audit),
      (label: 'Settings', icon: Icons.settings_outlined, route: RouteNames.settings),
    ];
    final chips = items
        .map(
          (e) => _ShortcutChip(
            label: e.label,
            icon: e.icon,
            onTap: () => context.go(e.route),
          ),
        )
        .toList(growable: false);

    if (wide) {
      return AdminSurfaceCard(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Wrap(
          spacing: AdminSpacing.sm,
          runSpacing: AdminSpacing.sm,
          children: chips,
        ),
      );
    }
    return AdminSurfaceCard(
      padding: const EdgeInsets.symmetric(
        vertical: AdminSpacing.sm,
        horizontal: AdminSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: AdminSpacing.sm),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.primarySubtle,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AdminColors.primaryAction.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AdminColors.primaryAction),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditPanel extends StatelessWidget {
  const _AuditPanel({required this.logs});

  final List<AuditLog> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (logs.isEmpty) {
      return AdminSurfaceCard(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.borderSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                color: AdminColors.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: AdminSpacing.md),
            Expanded(
              child: Text(
                'No audit entries yet, or the list is empty.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AdminColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: () => context.go(RouteNames.audit),
              child: const Text('Open audit log'),
            ),
          ],
        ),
      );
    }
    return AdminSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++) ...[
            _AuditRow(log: logs[i]),
            if (i < logs.length - 1)
              const Divider(height: 1, color: AdminColors.borderSubtle),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.go(RouteNames.audit),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Full audit log'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actor = (log.actorName ?? '').trim().isNotEmpty
        ? log.actorName!.trim()
        : 'System';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(RouteNames.audit),
        hoverColor: AdminColors.rowHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AdminColors.primaryAction,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${log.action} · ${log.entityType} · $actor · ${DashboardScreen._fmtWhen(log.occurredAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartialBanner extends StatelessWidget {
  const _PartialBanner({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C)),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Some dashboard metrics could not load',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9A3412),
                      ),
                ),
                const SizedBox(height: 6),
                ...errors.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      e,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFC2410C),
                            height: 1.35,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AdminSurfaceCard(
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminColors.dangerSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 36,
                  color: AdminColors.danger,
                ),
              ),
              const SizedBox(height: AdminSpacing.md),
              Text(
                'Could not load dashboard',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: AdminSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AdminColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AdminSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, [double? w]) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: AdminColors.borderSubtle,
            borderRadius: BorderRadius.circular(10),
          ),
        );
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bar(28, 200),
              const SizedBox(height: AdminSpacing.sm),
              bar(14, 320),
              const SizedBox(height: AdminSpacing.lg),
              bar(148, double.infinity),
              const SizedBox(height: AdminSpacing.lg + AdminSpacing.xs),
              bar(18, 100),
              const SizedBox(height: AdminSpacing.md),
              Row(
                children: [
                  Expanded(child: bar(108, double.infinity)),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(child: bar(108, double.infinity)),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(child: bar(108, double.infinity)),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(child: bar(108, double.infinity)),
                ],
              ),
              const SizedBox(height: AdminSpacing.lg + AdminSpacing.xs),
              bar(18, 100),
              const SizedBox(height: AdminSpacing.md),
              bar(56, double.infinity),
            ],
          ),
        ),
      ),
    );
  }
}
