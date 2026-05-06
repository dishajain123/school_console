import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging/crash_reporter.dart';
import 'core/router/app_router.dart';
import 'core/theme/admin_app_theme.dart';
import 'domains/providers/auth_provider.dart';

void main() {
  _configureErrorWidget();
  runApp(const ProviderScope(child: AdminConsoleApp()));
}

/// Friendly build-error surface in release/profile; default [ErrorWidget] in debug.
void _configureErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    CrashReporter.log(
      details.exception,
      details.stack,
    );
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    return const _FriendlyBuildErrorPlaceholder();
  };
}

class _FriendlyBuildErrorPlaceholder extends StatelessWidget {
  const _FriendlyBuildErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F4F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey.shade600),
              const SizedBox(height: 20),
              Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please refresh the page or try again later. If the problem continues, contact support.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminConsoleApp extends ConsumerWidget {
  const AdminConsoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(authBootstrapProvider);

    if (bootstrap.isLoading) {
      const loadingScaffold = Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
      return MaterialApp(
        title: 'Admin Console',
        debugShowCheckedModeBanner: false,
        home: loadingScaffold,
        routes: {
          '/login': (_) => loadingScaffold,
        },
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => loadingScaffold),
      );
    }

    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Admin Console',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      routerConfig: router,
    );
  }
}
