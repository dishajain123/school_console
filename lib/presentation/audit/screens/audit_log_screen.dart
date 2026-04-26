import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/providers/audit_provider.dart';
import '../../common/layout/admin_scaffold.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(auditLogProvider);

    return AdminScaffold(
      title: 'Approval Audit Log',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: logs.when(
          data: (items) => ListView.separated(
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text('${item.action} • user ${item.userId}'),
                subtitle: Text(
                  'by ${item.actedById} | ${item.fromStatus ?? '-'} -> ${item.toStatus ?? '-'}\n${item.note ?? ''}',
                ),
                trailing: Text(item.actedAt.toIso8601String()),
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemCount: items.length,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
        ),
      ),
    );
  }
}
