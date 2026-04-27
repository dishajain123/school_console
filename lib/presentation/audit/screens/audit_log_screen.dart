// lib/presentation/audit/screens/audit_log_screen.dart  [Admin Console]
// Phase 14 — Audit & Traceability.
// FIXED: screen now uses the corrected AuditLog model (occurredAt, entityType,
//        entityId, description, actorName, beforeState, afterState).
// FIXED: calls /audit-logs (not /approvals/audit/logs).
// Features: filter by action, entity type, date range, free-text search.
//           Paginated. Expandable rows to view before/after state.
//           SUPERADMIN sees all schools; PRINCIPAL sees own school only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/audit/audit_log.dart';
import '../../../domains/providers/audit_provider.dart';
import '../../common/layout/admin_scaffold.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final _searchCtrl = TextEditingController();
  final _actorCtrl = TextEditingController();

  String? _selectedAction;
  String? _selectedEntityType;
  String? _dateFrom;
  String? _dateTo;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _actorCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(auditLogFilterProvider.notifier).update(
          AuditLogFilter(
            action: _selectedAction,
            entityType: _selectedEntityType,
            actorId: _actorCtrl.text.trim().isEmpty
                ? null
                : _actorCtrl.text.trim(),
            q: _searchCtrl.text.trim().isEmpty
                ? null
                : _searchCtrl.text.trim(),
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            page: 1,
            pageSize: 50,
          ),
        );
  }

  void _resetFilters() {
    _searchCtrl.clear();
    _actorCtrl.clear();
    setState(() {
      _selectedAction = null;
      _selectedEntityType = null;
      _dateFrom = null;
      _dateTo = null;
    });
    ref.read(auditLogFilterProvider.notifier).reset();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final iso = picked.toIso8601String().substring(0, 10);
      setState(() {
        if (isFrom) {
          _dateFrom = iso;
        } else {
          _dateTo = iso;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(auditLogProvider);
    final actions = ref.watch(auditActionsProvider);
    final entityTypes = ref.watch(auditEntityTypesProvider);

    return AdminScaffold(
      title: 'Audit Log',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filter Section ────────────────────────────────────────────
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Action filter
                        SizedBox(
                          width: 200,
                          child: actions.when(
                            data: (list) => DropdownButtonFormField<String?>(
                              value: _selectedAction,
                              decoration: const InputDecoration(
                                labelText: 'Action',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                    value: null, child: Text('All')),
                                ...list.map((a) => DropdownMenuItem<String>(
                                    value: a, child: Text(a))),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedAction = v),
                            ),
                            loading: () => const SizedBox(
                                height: 40,
                                child: Center(
                                    child: LinearProgressIndicator())),
                            error: (_, __) => const Text('—'),
                          ),
                        ),
                        // Entity type filter
                        SizedBox(
                          width: 220,
                          child: entityTypes.when(
                            data: (list) =>
                                DropdownButtonFormField<String?>(
                              value: _selectedEntityType,
                              decoration: const InputDecoration(
                                labelText: 'Entity Type',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                    value: null, child: Text('All')),
                                ...list.map((e) => DropdownMenuItem<String>(
                                    value: e, child: Text(e))),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedEntityType = v),
                            ),
                            loading: () => const SizedBox(
                                height: 40,
                                child: Center(
                                    child: LinearProgressIndicator())),
                            error: (_, __) => const Text('—'),
                          ),
                        ),
                        // Search text
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Search description',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                            onSubmitted: (_) => _applyFilters(),
                          ),
                        ),
                        // Actor ID
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _actorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Actor ID (UUID)',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                            onSubmitted: (_) => _applyFilters(),
                          ),
                        ),
                        // Date From
                        OutlinedButton.icon(
                          icon: const Icon(Icons.date_range, size: 14),
                          label: Text(_dateFrom != null
                              ? 'From: $_dateFrom'
                              : 'From Date'),
                          onPressed: () => _pickDate(isFrom: true),
                        ),
                        // Date To
                        OutlinedButton.icon(
                          icon: const Icon(Icons.date_range, size: 14),
                          label: Text(
                              _dateTo != null ? 'To: $_dateTo' : 'To Date'),
                          onPressed: () => _pickDate(isFrom: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.search, size: 14),
                          label: const Text('Apply Filters'),
                          onPressed: _applyFilters,
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.clear, size: 14),
                          label: const Text('Reset'),
                          onPressed: _resetFilters,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Log List ──────────────────────────────────────────────────
            Expanded(
              child: logs.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(e.toString(),
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(auditLogProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No audit log entries found for the selected filters.',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _AuditLogTile(log: item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single log entry tile ─────────────────────────────────────────────────────

class _AuditLogTile extends StatefulWidget {
  const _AuditLogTile({required this.log});
  final AuditLog log;

  @override
  State<_AuditLogTile> createState() => _AuditLogTileState();
}

class _AuditLogTileState extends State<_AuditLogTile> {
  bool _expanded = false;

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}:${l.second.toString().padLeft(2, '0')}';
  }

  Color _actionColor(String action) {
    final a = action.toUpperCase();
    if (a.contains('APPROVE') || a.contains('ENROLL') || a.contains('CREATE')) {
      return Colors.green;
    }
    if (a.contains('REJECT') || a.contains('DELETE') || a.contains('EXIT')) {
      return Colors.red;
    }
    if (a.contains('PROMOTE') || a.contains('UPDATE') || a.contains('EDIT')) {
      return Colors.blue;
    }
    if (a.contains('HOLD') || a.contains('SUSPEND')) {
      return Colors.orange;
    }
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final hasStateChanges =
        log.beforeState != null || log.afterState != null;

    return InkWell(
      onTap: hasStateChanges
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        _actionColor(log.action).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _actionColor(log.action).withOpacity(0.5)),
                  ),
                  child: Text(
                    log.action,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _actionColor(log.action),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Entity type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(
                    log.entityType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                // Timestamp
                Text(
                  _formatDate(log.occurredAt),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
                if (hasStateChanges) ...[
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Description
            Text(
              log.description,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            // Actor + Entity ID row
            Wrap(
              spacing: 16,
              children: [
                if (log.actorName != null || log.actorId != null)
                  _InfoChip(
                    icon: Icons.person_outline,
                    label:
                        'Actor: ${log.actorName ?? log.actorId ?? '-'}',
                  ),
                if (log.targetUserId != null)
                  _InfoChip(
                    icon: Icons.account_circle_outlined,
                    label: 'Target: ${log.targetUserId}',
                  ),
                if (log.entityId != null)
                  _InfoChip(
                    icon: Icons.tag,
                    label: 'ID: ${log.entityId}',
                  ),
                if (log.ipAddress != null)
                  _InfoChip(
                    icon: Icons.lan_outlined,
                    label: 'IP: ${log.ipAddress}',
                  ),
              ],
            ),
            // Before/after state expansion
            if (_expanded && hasStateChanges) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (log.beforeState != null)
                    Expanded(
                      child: _StateBox(
                        title: 'Before',
                        color: Colors.red.shade50,
                        borderColor: Colors.red.shade200,
                        data: log.beforeState!,
                      ),
                    ),
                  if (log.beforeState != null && log.afterState != null)
                    const SizedBox(width: 8),
                  if (log.afterState != null)
                    Expanded(
                      child: _StateBox(
                        title: 'After',
                        color: Colors.green.shade50,
                        borderColor: Colors.green.shade200,
                        data: log.afterState!,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _StateBox extends StatelessWidget {
  const _StateBox({
    required this.title,
    required this.color,
    required this.borderColor,
    required this.data,
  });

  final String title;
  final Color color;
  final Color borderColor;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ...data.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${e.key}: ${e.value}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}