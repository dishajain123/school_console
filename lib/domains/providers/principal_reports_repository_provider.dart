import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/principal_reports_repository.dart';
import 'auth_provider.dart';

final principalReportsRepositoryProvider = Provider<PrincipalReportsRepository>(
  (ref) => PrincipalReportsRepository(ref.watch(dioClientProvider)),
);
