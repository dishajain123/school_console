import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_document_repository.dart';
import 'auth_provider.dart';

final adminDocumentRepositoryProvider = Provider<AdminDocumentRepository>(
  (ref) => AdminDocumentRepository(ref.watch(dioClientProvider)),
);
