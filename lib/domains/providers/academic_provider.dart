import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/academic_repository.dart';
import 'auth_provider.dart';

final academicRepositoryProvider = Provider<AcademicRepository>(
  (ref) => AcademicRepository(ref.watch(dioClientProvider)),
);
