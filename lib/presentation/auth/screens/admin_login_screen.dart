// lib/presentation/auth/screens/admin_login_screen.dart  [Admin Console]
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_constants.dart';
import '../../../data/models/auth/admin_user.dart';
import '../../../domains/providers/auth_provider.dart';
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

  // Determine where to land after login based on the user's role/permissions.
  // Phase 5 requirement: each role type lands on their primary module.
  String _resolveInitialRoute(AdminUser user) {
    final role = user.role.toUpperCase();

    // SUPERADMIN: primary responsibility is system configuration
    if (role == 'SUPERADMIN') {
      return RouteNames.settings;
    }

    // Accounts staff: primary responsibility is fee management
    // They have fee:read but typically NOT approval:review
    if (!user.canReview && user.permissions.contains('fee:read')) {
      return RouteNames.fees;
    }

    // All others (PRINCIPAL, STAFF with review perm): primary is approvals queue
    return RouteNames.approvals;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Admin Console Login',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  LoginForm(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
