// lib/domains/providers/audit_provider.dart  [Admin Console]
// Phase 14 — Audit & Traceability.
// FIXED: auditLogProvider now accepts filter parameters via AuditLogFilter.
// Added auditActionsProvider and auditEntityTypesProvider for filter dropdowns.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/audit/audit_log.dart';
import '../../data/repositories/audit_repository.dart';
import 'auth_provider.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(ref.watch(dioClientProvider)),
);

// ── Filter model ──────────────────────────────────────────────────────────────

class AuditLogFilter {
  const AuditLogFilter({
    this.action,
    this.entityType,
    this.actorId,
    this.targetUserId,
    this.dateFrom,
    this.dateTo,
    this.q,
    this.page = 1,
    this.pageSize = 50,
  });

  final String? action;
  final String? entityType;
  final String? actorId;
  final String? targetUserId;
  final String? dateFrom;
  final String? dateTo;
  final String? q;
  final int page;
  final int pageSize;

  AuditLogFilter copyWith({
    String? action,
    String? entityType,
    String? actorId,
    String? targetUserId,
    String? dateFrom,
    String? dateTo,
    String? q,
    int? page,
    int? pageSize,
  }) =>
      AuditLogFilter(
        action: action ?? this.action,
        entityType: entityType ?? this.entityType,
        actorId: actorId ?? this.actorId,
        targetUserId: targetUserId ?? this.targetUserId,
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
        q: q ?? this.q,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );

  AuditLogFilter clearAction() => AuditLogFilter(
        entityType: entityType,
        actorId: actorId,
        targetUserId: targetUserId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        q: q,
        page: page,
        pageSize: pageSize,
      );

  AuditLogFilter clearEntityType() => AuditLogFilter(
        action: action,
        actorId: actorId,
        targetUserId: targetUserId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        q: q,
        page: page,
        pageSize: pageSize,
      );
}

// ── Filter state notifier ─────────────────────────────────────────────────────

class AuditLogFilterNotifier extends StateNotifier<AuditLogFilter> {
  AuditLogFilterNotifier() : super(const AuditLogFilter());

  void update(AuditLogFilter filter) => state = filter;
  void reset() => state = const AuditLogFilter();
}

final auditLogFilterProvider =
    StateNotifierProvider<AuditLogFilterNotifier, AuditLogFilter>(
  (ref) => AuditLogFilterNotifier(),
);

// ── Data provider (reacts to filter changes) ──────────────────────────────────

final auditLogProvider = FutureProvider<List<AuditLog>>((ref) async {
  final filter = ref.watch(auditLogFilterProvider);
  return ref.watch(auditRepositoryProvider).list(
        page: filter.page,
        pageSize: filter.pageSize,
        action: filter.action,
        entityType: filter.entityType,
        actorId: filter.actorId,
        targetUserId: filter.targetUserId,
        dateFrom: filter.dateFrom,
        dateTo: filter.dateTo,
        q: filter.q,
      );
});

// ── Dropdown helpers ──────────────────────────────────────────────────────────

final auditActionsProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(auditRepositoryProvider).listActions();
});

final auditEntityTypesProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(auditRepositoryProvider).listEntityTypes();
});