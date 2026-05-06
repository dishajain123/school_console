import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/announcement_repository.dart';
import 'auth_provider.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepository(ref.watch(dioClientProvider)),
);
