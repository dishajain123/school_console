import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/results_repository.dart';
import 'auth_provider.dart';

final resultsRepositoryProvider = Provider<ResultsRepository>(
  (ref) => ResultsRepository(ref.watch(dioClientProvider)),
);
