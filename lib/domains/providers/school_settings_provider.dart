import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository_providers.dart';

/// School/system settings list from the API — invalidate after updates.
final schoolSettingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(settingsRepositoryProvider).getSettings();
});
