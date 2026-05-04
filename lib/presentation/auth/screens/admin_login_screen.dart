// lib/presentation/auth/screens/admin_login_screen.dart  [Admin Console]
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/brand_constants.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../data/models/auth/admin_user.dart';
import '../../../domains/providers/auth_provider.dart';
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

    if (role == 'SUPERADMIN') {
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Base wash
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.38, 1.0],
                colors: [
                  const Color(0xFFEEF0FF),
                  AdminColors.canvas,
                  const Color(0xFFE4E9F2),
                ],
              ),
            ),
          ),
          // Soft brand glow
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.85, -0.95),
                radius: 1.15,
                colors: [
                  AdminColors.primaryAction.withValues(alpha: 0.09),
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
                  AdminColors.primaryAction.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Fine top sheen
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
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
        color: AdminColors.surface.withValues(alpha: 0.92),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.10),
            blurRadius: 56,
            offset: const Offset(0, 28),
            spreadRadius: -12,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AdminColors.primaryAction.withValues(alpha: 0.14),
                        blurRadius: 28,
                        spreadRadius: -6,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const SchoolBrandLogo(
                    height: 92,
                    borderRadius: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 6),
              Text(
                BrandConstants.adminConsoleTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AdminColors.primaryAction,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                BrandConstants.signInTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AdminColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
