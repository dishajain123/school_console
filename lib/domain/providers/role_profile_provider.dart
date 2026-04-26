import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/role_profile_repository.dart';
import 'auth_provider.dart';

final roleProfileRepositoryProvider = Provider<RoleProfileRepository>(
  (ref) => RoleProfileRepository(ref.watch(dioClientProvider)),
);
