import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/audit/audit_log.dart';
import '../../data/repositories/audit_repository.dart';
import 'auth_provider.dart';

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(ref.watch(dioClientProvider)),
);

final auditLogProvider = FutureProvider<List<AuditLog>>((ref) async {
  return ref.watch(auditRepositoryProvider).list();
});
