import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/lifecycle/lifecycle_models.dart';
import '../../data/repositories/lifecycle_admin_repository.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// Academic years + standards for lifecycle filter dropdowns.
class LifecycleMetaBundle {
  const LifecycleMetaBundle({
    required this.years,
    required this.standards,
  });

  final List<LifecycleAcademicYear> years;
  final List<LifecycleStandard> standards;
}

final lifecycleMetaProvider =
    FutureProvider.autoDispose<LifecycleMetaBundle>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null) {
    return const LifecycleMetaBundle(years: [], standards: []);
  }
  final repo =
      LifecycleAdminRepository(ref.watch(enrollmentRepositoryProvider));
  final results = await Future.wait([
    repo.getAcademicYears(),
    repo.getStandards(),
  ]);
  return LifecycleMetaBundle(
    years: results[0] as List<LifecycleAcademicYear>,
    standards: results[1] as List<LifecycleStandard>,
  );
});
