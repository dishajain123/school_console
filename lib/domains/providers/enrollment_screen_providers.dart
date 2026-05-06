import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'repository_providers.dart';

/// Academic years for the signed-in school (enrollment API).
final schoolEnrollmentYearsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final schoolId = ref.watch(authControllerProvider).valueOrNull?.schoolId;
  if (schoolId == null) return const [];
  return ref.watch(enrollmentRepositoryProvider).listAcademicYears(
        schoolId: schoolId,
      );
});

/// Parameterizes onboarding queue fetch for [EnrollmentScreen].
class OnboardingQueueKey {
  const OnboardingQueueKey({
    required this.academicYearId,
    this.role,
  });

  final String academicYearId;
  final String? role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingQueueKey &&
          runtimeType == other.runtimeType &&
          academicYearId == other.academicYearId &&
          role == other.role;

  @override
  int get hashCode => Object.hash(academicYearId, role);
}

final onboardingQueueProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, OnboardingQueueKey>((ref, key) async {
  return ref.watch(enrollmentRepositoryProvider).onboardingQueue(
        role: key.role,
        pendingOnly: false,
        academicYearId: key.academicYearId,
      );
});
