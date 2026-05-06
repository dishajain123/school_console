import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/teacher_assignments_repository.dart';
import 'auth_provider.dart';

final teacherAssignmentsRepositoryProvider =
    Provider<TeacherAssignmentsRepository>(
  (ref) => TeacherAssignmentsRepository(ref.watch(dioClientProvider)),
);
