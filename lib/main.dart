import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domains/providers/auth_provider.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: AdminConsoleApp()));
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
