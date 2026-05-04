// lib/presentation/auth/screens/admin_login_screen.dart  [Admin Console]
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

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  String? _error;
  String _cleanErrorText(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }

  String _resolveInitialRoute(AdminUser user) {
    final role = user.role.toUpperCase();

    if (role == 'STAFF_ADMIN') {
      return RouteNames.settings;
    }

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
          setState(() {
            _error = _cleanErrorText(error);
          });
        },
      );
    });

    return Scaffold(
      backgroundColor: AdminColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.38, 1.0],
                  colors: [
                    AdminColors.primarySubtle.withValues(alpha: 0.55),
                    AdminColors.canvas,
                    const Color(0xFFE4E9F2),
                  ],
                ),
              ),
            ),
          DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.95),
                  radius: 1.15,
                  colors: [
                    AdminColors.primaryAction.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.1, 0.85),
                  radius: 1.0,
                  colors: [
                    AdminColors.primaryAction.withValues(alpha: 0.045),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment(0, 0.22),
                  colors: [
                    Color(0x33FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          Center(
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
                        setState(() {
                          _error = null;
                        });
                        final isEmail = credential.contains('@');
                        await ref.read(authControllerProvider.notifier).login(
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
        ],
      ),
    );
  }
}

class _LoginHeroCard extends StatelessWidget {
  const _LoginHeroCard({
    required this.theme,
    required this.child,
  });

  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AdminColors.surface.withValues(alpha: 0.96),
        border: Border.all(
          color: AdminColors.border.withValues(alpha: 0.85),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AdminColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 48,
            offset: const Offset(0, 24),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: AdminColors.primaryAction.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: SchoolBrandLogo(
                  height: 88,
                  borderRadius: 14,
                ),
              ),
              const SizedBox(height: AdminSpacing.lg),
              Text(
                BrandConstants.schoolDisplayName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1.15,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: AdminSpacing.xs),
              Text(
                BrandConstants.adminConsoleTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AdminColors.primaryAction,
                ),
              ),
              const SizedBox(height: AdminSpacing.xs),
              Text(
                BrandConstants.signInTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AdminColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AdminSpacing.lg),
              const Divider(
                height: 1,
                thickness: 1,
                color: AdminColors.borderSubtle,
              ),
              const SizedBox(height: AdminSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
