import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/brand_constants.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/auth/admin_user.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/school_brand_logo.dart';
import '../widgets/login_form.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  String? _error;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  String _cleanErrorText(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }

  String _resolveInitialRoute(AdminUser user) {
    final role = user.role.toUpperCase();
    if (role == 'STAFF_ADMIN') return RouteNames.settings;
    if (!user.canReview && user.permissions.contains('fee:read')) {
      return RouteNames.fees;
    }
    return RouteNames.approvals;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    ref.listen<AsyncValue<AdminUser?>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null && context.mounted) {
            context.go(_resolveInitialRoute(user));
          }
        },
        error: (error, _) {
          setState(() => _error = _cleanErrorText(error));
        },
      );
    });

    return Scaffold(
      backgroundColor: AdminColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Base gradient ──────────────────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  AdminColors.primarySubtle.withValues(alpha: 0.6),
                  AdminColors.canvas,
                  const Color(0xFFDDE3F0),
                ],
              ),
            ),
          ),

          // ── Radial top-left glow ───────────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.9, -0.9),
                radius: 1.2,
                colors: [
                  AdminColors.primaryAction.withValues(alpha: 0.11),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // ── Radial bottom-right glow ───────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1.1, 1.0),
                radius: 1.0,
                colors: [
                  AdminColors.primaryAction.withValues(alpha: 0.055),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // ── Decorative geometric arcs ──────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BackgroundArcPainter(
                  color: AdminColors.primaryAction.withValues(alpha: 0.055),
                ),
              ),
            ),
          ),

          // ── Card (animated entrance) ───────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.pagePadding,
                    vertical: AdminSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _LoginHeroCard(
                      theme: theme,
                      child: LoginForm(
                        loading: authState.isLoading,
                        errorText: _error,
                        onSubmit: (credential, password) async {
                          setState(() => _error = null);
                          final isEmail = credential.contains('@');
                          await ref
                              .read(authControllerProvider.notifier)
                              .login(
                                email: isEmail ? credential : null,
                                phone: isEmail ? null : credential,
                                password: password,
                              );
                          if (!context.mounted) return;
                          final next = ref.read(authControllerProvider);
                          final user = next.valueOrNull;
                          if (user != null) {
                            context.go(_resolveInitialRoute(user));
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decorative background arcs ─────────────────────────────────────────────
class _BackgroundArcPainter extends CustomPainter {
  const _BackgroundArcPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Top-left arc cluster
    for (int i = 1; i <= 4; i++) {
      final r = size.width * 0.18 * i;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.08, size.height * 0.06),
          width: r * 2,
          height: r * 2,
        ),
        math.pi * 0.25,
        math.pi * 0.9,
        false,
        paint,
      );
    }

    // Bottom-right arc cluster
    for (int i = 1; i <= 3; i++) {
      final r = size.width * 0.2 * i;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.95, size.height * 0.94),
          width: r * 2,
          height: r * 2,
        ),
        math.pi * 1.1,
        math.pi * 0.85,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BackgroundArcPainter old) => old.color != color;
}

// ── Premium hero card ──────────────────────────────────────────────────────
class _LoginHeroCard extends StatelessWidget {
  const _LoginHeroCard({required this.theme, required this.child});
  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AdminColors.surface.withValues(alpha: 0.97),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AdminColors.textPrimary.withValues(alpha: 0.07),
            blurRadius: 64,
            offset: const Offset(0, 28),
            spreadRadius: -10,
          ),
          BoxShadow(
            color: AdminColors.primaryAction.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 14),
            spreadRadius: -16,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 0,
            offset: const Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.lg,
            AdminSpacing.lg,
            AdminSpacing.lg,
            AdminSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo with a premium ring decoration
              Center(
                child: _LogoBadge(),
              ),
              const SizedBox(height: AdminSpacing.md),

              // Console title — indigo pill chip
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.primaryAction.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AdminColors.primaryAction.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    BrandConstants.adminConsoleTitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: AdminColors.primaryAction,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AdminSpacing.sm),

              // Tagline
              Text(
                BrandConstants.signInTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AdminColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AdminSpacing.lg),

              // Subtle divider with "sign in" label
              _SectionDivider(),
              const SizedBox(height: AdminSpacing.lg),

              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: AdminColors.border.withValues(alpha: 0.5),
          width: 1.25,
        ),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primaryAction.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: const SchoolBrandLogo(
        height: 110,
        borderRadius: 100,
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: AdminColors.borderSubtle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Sign in to continue',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AdminColors.textSecondary,
                  letterSpacing: 0.3,
                ),
          ),
        ),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: AdminColors.borderSubtle,
          ),
        ),
      ],
    );
  }
}