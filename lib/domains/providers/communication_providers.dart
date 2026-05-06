import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/crash_reporter.dart';
import '../../data/models/communication/admin_announcement_models.dart';
import 'active_year_provider.dart';
import 'repository_providers.dart';

/// School announcements list for the Communication screen.
final announcementsListProvider =
    FutureProvider.autoDispose<List<AdminAnnouncementItem>>((ref) async {
  final repo = ref.watch(announcementRepositoryProvider);
  final raw = await repo.listAnnouncements();
  return raw.map((e) => AdminAnnouncementItem.fromJson(e)).toList();
});

/// Standards dropdown options for announcement targeting (uses active year when set).
final announcementStandardsProvider =
    FutureProvider.autoDispose<List<AdminStandardOption>>((ref) async {
  final repo = ref.watch(announcementRepositoryProvider);
  try {
    String? yearId = ref.watch(activeAcademicYearProvider);
    if (yearId == null) {
      final years = await repo.listAcademicYears();
      final active = years.firstWhere(
        (y) => y['is_active'] == true,
        orElse: () => years.isNotEmpty ? years.first : <String, dynamic>{},
      );
      yearId = active['id']?.toString();
    }
    final maps =
        await repo.listStandardsMaps(academicYearId: yearId);
    return maps
        .map(
          (m) => AdminStandardOption(
            id: m['id']?.toString() ?? '',
            name: m['name']?.toString() ?? '-',
          ),
        )
        .where((s) => s.id.isNotEmpty)
        .toList();
  } catch (e, stack) {
    CrashReporter.log(e, stack);
    return const [];
  }
});
