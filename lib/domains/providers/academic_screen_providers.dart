import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository_providers.dart';
import 'auth_provider.dart';

/// Academic year rows for [AcademicStructureScreen] (masters/academic API shape).
final academicStructureYearsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final schoolId = ref.watch(authControllerProvider).valueOrNull?.schoolId;
  if (schoolId == null) return const [];
  return ref.watch(academicRepositoryProvider).listAcademicYearMaps(
        schoolId: schoolId,
      );
});
