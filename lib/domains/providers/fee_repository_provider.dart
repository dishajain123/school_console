import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/fee_repository.dart';
import 'auth_provider.dart';

final feeRepositoryProvider = Provider<FeeRepository>(
  (ref) => FeeRepository(ref.watch(dioClientProvider)),
);
