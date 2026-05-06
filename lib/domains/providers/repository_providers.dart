import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/academic_repository.dart';
import '../../data/repositories/admin_document_repository.dart';
import '../../data/repositories/announcement_repository.dart';
import '../../data/repositories/enrollment_repository.dart';
import '../../data/repositories/role_profile_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'auth_provider.dart';

final academicRepositoryProvider = Provider<AcademicRepository>(
  (ref) => AcademicRepository(ref.watch(dioClientProvider)),
);

final adminDocumentRepositoryProvider = Provider<AdminDocumentRepository>(
  (ref) => AdminDocumentRepository(ref.watch(dioClientProvider)),
);

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepository(ref.watch(dioClientProvider)),
);

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>(
  (ref) => EnrollmentRepository(ref.watch(dioClientProvider)),
);

final roleProfileRepositoryProvider = Provider<RoleProfileRepository>(
  (ref) => RoleProfileRepository(ref.watch(dioClientProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(dioClientProvider)),
);
