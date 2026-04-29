import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/enrollment_repository.dart';
import 'auth_provider.dart';

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>(
  (ref) => EnrollmentRepository(ref.watch(dioClientProvider)),
);
