import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/academics/academic_phase3_overview.dart';
import '../../data/models/academics/academic_year_item.dart';
import 'repository_providers.dart';
import 'auth_provider.dart';

/// Query for [academicPhase3Provider]: which year to preview + bump [reloadNonce] to refetch.
@immutable
class AcademicPhase3Query {
  const AcademicPhase3Query({
    this.previewYearId,
    required this.reloadNonce,
  });

  final String? previewYearId;
  final int reloadNonce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AcademicPhase3Query &&
          previewYearId == other.previewYearId &&
          reloadNonce == other.reloadNonce;

  @override
  int get hashCode => Object.hash(previewYearId, reloadNonce);
}

/// Loads school academic structure for the Academic Years UI (single overview fetch).
final academicPhase3Provider = FutureProvider.autoDispose
    .family<AcademicPhase3Overview, AcademicPhase3Query>((ref, query) async {
      final auth = ref.watch(authControllerProvider).valueOrNull;
      final repo = ref.watch(academicRepositoryProvider);
      final schoolId = await repo.resolveSchoolId(auth?.schoolId);
      final years = await repo.listYears(schoolId: schoolId);
      final active = years
          .where((y) => y.isActive)
          .cast<AcademicYearItem?>()
          .firstWhere(
            (y) => y != null,
            orElse: () => years.isNotEmpty ? years.first : null,
          );
      final yearId = (query.previewYearId != null &&
              years.any((y) => y.id == query.previewYearId))
          ? query.previewYearId
          : active?.id;
      final standards = await repo.listStandards(
        schoolId: schoolId,
        academicYearId: yearId,
      );
      final sections = await repo.listSections(
        schoolId: schoolId,
        academicYearId: yearId,
      );
      final subjects = await repo.listSubjects(schoolId: schoolId);
      return AcademicPhase3Overview(
        schoolId: schoolId,
        years: years,
        activeYearId: yearId,
        standards: standards,
        sections: sections,
        subjects: subjects,
      );
    });
