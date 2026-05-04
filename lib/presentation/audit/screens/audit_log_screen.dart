// lib/presentation/audit/screens/audit_log_screen.dart  [Admin Console]
// Phase 14 — Audit & Traceability.
// FIXED: screen now uses the corrected AuditLog model (occurredAt, entityType,
//        entityId, description, actorName, beforeState, afterState).
// FIXED: calls /audit-logs (not /approvals/audit/logs).
// Features: filter by action, entity type, date range.
//           Paginated. Expandable rows to view before/after state.
//           STAFF_ADMIN sees all schools; PRINCIPAL sees own school only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../data/models/audit/audit_log.dart';
import '../../../domains/providers/audit_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_filter_card.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String? _selectedAction;
  String? _selectedEntityType;
  String? _dateFrom;
  String? _dateTo;

  void _applyFilters() {
    ref.read(auditLogFilterProvider.notifier).update(
          AuditLogFilter(
            action: _selectedAction,
            entityType: _selectedEntityType,
            q: null,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            page: 1,
            pageSize: 50,
          ),
        );
  }

  void _resetFilters() {
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
      title: 'Audit log',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminPageHeader(
              title: 'Audit log',
              subtitle:
                  'Trace admin actions with filters and pagination. Expand rows to compare before/after state.',
            ),
            AdminFilterCard(
              onReset: _resetFilters,
              child: Wrap(
                    spacing: AdminSpacing.sm,
                    runSpacing: AdminSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                        // Action filter
                        SizedBox(
                          width: 200,
                          child: actions.when(
                            data: (list) => DropdownButtonFormField<String?>(
                              key: ValueKey<String?>(
                                  'audit_action_${_selectedAction ?? 'null'}'),
                              initialValue: _selectedAction,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Action',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'All',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ...list.map((a) => DropdownMenuItem<String>(
                                      value: a,
                                      child: Text(
                                        a,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                              ],
                              selectedItemBuilder: (context) {
                                return [
                                  const Text(
                                    'All',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  ...list.map(
                                    (a) => Text(
                                      a,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ];
                              },
                              onChanged: (v) =>
                                  setState(() => _selectedAction = v),
                            ),
                            loading: () => const SizedBox(
                              height: 40,
                              child: Center(
                                child: LinearProgressIndicator(
                                  minHeight: 2,
                                  color: AdminColors.primaryAction,
                                  backgroundColor: AdminColors.borderSubtle,
                                ),
                              ),
                            ),
                            error: (_, _) => const Text('—'),
                          ),
                        ),
                        // Entity type filter
                        SizedBox(
                          width: 220,
                          child: entityTypes.when(
                            data: (list) =>
                                DropdownButtonFormField<String?>(
                              key: ValueKey<String?>(
                                  'audit_entity_${_selectedEntityType ?? 'null'}'),
                              initialValue: _selectedEntityType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Entity Type',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'All',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ...list.map((e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(
                                        e,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                              ],
                              selectedItemBuilder: (context) {
                                return [
                                  const Text(
                                    'All',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  ...list.map(
                                    (e) => Text(
                                      e,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ];
                              },
                              onChanged: (v) =>
                                  setState(() => _selectedEntityType = v),
                            ),
                            loading: () => const SizedBox(
                              height: 40,
                              child: Center(
                                child: LinearProgressIndicator(
                                  minHeight: 2,
                                  color: AdminColors.primaryAction,
                                  backgroundColor: AdminColors.borderSubtle,
                                ),
                              ),
                            ),
                            error: (_, _) => const Text('—'),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.search_rounded, size: 18),
                              label: const Text('Apply filters'),
                              onPressed: _applyFilters,
                            ),
                          ),
                        ),
                        // Date From
                        OutlinedButton.icon(
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(_dateFrom != null
                              ? 'From: $_dateFrom'
                              : 'From Date'),
                          onPressed: () => _pickDate(isFrom: true),
                        ),
                        // Date To
                        OutlinedButton.icon(
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                              _dateTo != null ? 'To: $_dateTo' : 'To Date'),
                          onPressed: () => _pickDate(isFrom: false),
                        ),
                      ],
                    ),
              ),
            const SizedBox(height: AdminSpacing.sm),

            // ── Log List ──────────────────────────────────────────────────
            Expanded(
              child: logs.when(
                loading: () => const AdminLoadingPlaceholder(
                  message: 'Loading audit log…',
                  height: 320,
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.lg),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Material(
                        color: AdminColors.dangerSurface,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(AdminSpacing.md),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: AdminColors.danger,
                                    size: 28,
                                  ),
                                  const SizedBox(width: AdminSpacing.sm),
                                  Text(
                                    'Could not load audit log',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AdminColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AdminSpacing.sm),
                              SelectableText(
                                e.toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AdminColors.danger,
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: AdminSpacing.md),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 18),
                                  label: const Text('Retry'),
                                  onPressed: () =>
                                      ref.invalidate(auditLogProvider),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.history,
                      title: 'No audit entries',
                      message:
                          'Try widening filters or changing the date range, then apply again.',
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: AdminColors.border,
                    ),
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
      return AdminColors.success;
    }
    if (a.contains('REJECT') || a.contains('DELETE') || a.contains('EXIT')) {
      return AdminColors.danger;
    }
    if (a.contains('PROMOTE') || a.contains('UPDATE') || a.contains('EDIT')) {
      return AdminColors.primaryAction;
    }
    if (a.contains('HOLD') || a.contains('SUSPEND')) {
      return const Color(0xFFEA580C);
    }
    return AdminColors.textSecondary;
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
                    color: _actionColor(log.action)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _actionColor(log.action).withValues(alpha: 0.45),
                    ),
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
                    color: AdminColors.primarySubtle,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color:
                          AdminColors.primaryAction.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    log.entityType,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.primaryPressed,
                    ),
                  ),
                ),
                const Spacer(),
                // Timestamp
                Text(
                  _formatDate(log.occurredAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminColors.textMuted,
                  ),
                ),
                if (hasStateChanges) ...[
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: AdminColors.textMuted,
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
              const Divider(height: 1, color: AdminColors.border),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (log.beforeState != null)
                    Expanded(
                      child: _StateBox(
                        title: 'Before',
                        color: AdminColors.dangerSurface,
                        borderColor:
                            AdminColors.danger.withValues(alpha: 0.35),
                        data: log.beforeState!,
                      ),
                    ),
                  if (log.beforeState != null && log.afterState != null)
                    const SizedBox(width: 8),
                  if (log.afterState != null)
                    Expanded(
                      child: _StateBox(
                        title: 'After',
                        color: AdminColors.success.withValues(alpha: 0.1),
                        borderColor:
                            AdminColors.success.withValues(alpha: 0.4),
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
        Icon(icon, size: 12, color: AdminColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AdminColors.textSecondary,
          ),
        ),
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
